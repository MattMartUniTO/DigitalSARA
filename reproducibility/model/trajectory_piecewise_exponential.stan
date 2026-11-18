data {
  int<lower=2> K;
  vector[K] time_months;
  vector[K] logit_risk;
  vector<lower=0>[K] logit_se;
  real<lower=-0.99,upper=0.99> rho;
  real<lower=0> rw_prior_scale;
}
parameters {
  real log_hazard_1;
  vector[K-1] z_rw;
  real<lower=0> sigma_rw;
}
transformed parameters {
  vector[K] log_hazard_per_month;
  vector[K] risk;
  real cumulative_hazard = 0;
  real previous_time = 0;
  log_hazard_per_month[1] = log_hazard_1;
  for (k in 2:K)
    log_hazard_per_month[k] = log_hazard_per_month[k-1] + sigma_rw * z_rw[k-1];
  for (k in 1:K) {
    cumulative_hazard += exp(log_hazard_per_month[k]) * (time_months[k] - previous_time);
    risk[k] = 1 - exp(-cumulative_hazard);
    previous_time = time_months[k];
  }
}
model {
  matrix[K,K] Sigma;
  log_hazard_1 ~ normal(log(0.005), 1.5);
  z_rw ~ std_normal();
  sigma_rw ~ normal(0, rw_prior_scale);
  for (i in 1:K) {
    for (j in 1:K) {
      Sigma[i,j] = (i == j ? 1 : rho) * logit_se[i] * logit_se[j];
    }
  }
  logit_risk ~ multi_normal(logit(risk), Sigma);
}
generated quantities {
  vector[60] risk_monthly;
  for (m in 1:60) {
    real cumulative_hazard_m = 0;
    real time_reached = 0;
    for (k in 1:K) {
      real interval_end = fmin(m, time_months[k]);
      if (interval_end > time_reached) {
        cumulative_hazard_m += exp(log_hazard_per_month[k]) * (interval_end - time_reached);
        time_reached = interval_end;
      }
      if (time_reached >= m) break;
    }
    risk_monthly[m] = 1 - exp(-cumulative_hazard_m);
  }
}
