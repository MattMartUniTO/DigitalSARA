args <- commandArgs(trailingOnly=TRUE)
root <- if (length(args)) normalizePath(args[1], winslash='/', mustWork=TRUE) else normalizePath(file.path(dirname(sub('--file=', '', commandArgs()[grep('--file=', commandArgs())][1])), '..'), winslash='/', mustWork=TRUE)
infile <- file.path(root,'inputs','trajectory_inputs.csv')
outdir <- file.path(root,'outputs')
dir.create(outdir,recursive=TRUE,showWarnings=FALSE)
d <- read.csv(infile,stringsAsFactors=FALSE,check.names=FALSE,encoding='UTF-8')
if(nrow(d)==0) stop('No trajectory observations.')
if(any(!is.finite(d$logit_se_approx) | d$logit_se_approx<=0)) stop('Invalid logit-scale standard error.')
model_file <- file.path(root,'model','trajectory_piecewise_exponential.stan')
sm <- rstan::stan_model(file=model_file)
configs <- data.frame(config=c('primary_rho_0.50_rw_0.70','rho_0.00_rw_0.70','rho_0.90_rw_0.70','rho_0.50_rw_0.40','rho_0.50_rw_1.00'),
                      rho=c(0.50,0.00,0.90,0.50,0.50),rw_prior_scale=c(0.70,0.70,0.70,0.40,1.00),
                      stringsAsFactors=FALSE)
curve_rows <- list(); diag_rows <- list(); sens_rows <- list(); draw_store <- list(); ii <- 1; jj <- 1
for(arm_id in unique(d$technique_arm_id)) {
  x <- d[d$technique_arm_id==arm_id,,drop=FALSE]
  x <- x[order(x$time_months),,drop=FALSE]
  if(anyDuplicated(x$time_months)) stop(paste('Duplicate visit for',arm_id))
  dat_base <- list(K=nrow(x),time_months=as.numeric(x$time_months),logit_risk=qlogis(as.numeric(x$risk)),
                   logit_se=as.numeric(x$logit_se_approx))
  for(ci in seq_len(nrow(configs))) {
    cfg <- configs[ci,]
    dat <- c(dat_base,list(rho=cfg$rho,rw_prior_scale=cfg$rw_prior_scale))
    primary <- ci==1
    iter <- if(primary) 4000 else 2000
    warmup <- if(primary) 2000 else 1000
    fit <- rstan::sampling(sm,data=dat,chains=4,iter=iter,warmup=warmup,cores=4,
      seed=20261026+sum(utf8ToInt(arm_id))+ci,control=list(adapt_delta=0.999,max_treedepth=14),refresh=0)
    ex <- rstan::extract(fit,pars=c('risk_monthly','risk','sigma_rw','log_hazard_per_month'),permuted=TRUE)
    monthly <- ex$risk_monthly
    if(is.null(dim(monthly))) monthly <- matrix(monthly,ncol=60)
    smry <- t(apply(monthly,2,function(v)c(median=median(v),lower=unname(quantile(v,.025)),upper=unname(quantile(v,.975)))))
    if(primary) {
      for(m in 1:60) {
        curve_rows[[ii]] <- data.frame(study_id=x$study_id[1],technique_arm_id=arm_id,technique_id=x$technique_id[1],
          procedure_as_reported=x$procedure_as_reported[1],endpoint_class=x$endpoint_class[1],time_months=m,
          posterior_median=smry[m,'median'],lower95=smry[m,'lower'],upper95=smry[m,'upper'],
          rho=cfg$rho,rw_prior_scale=cfg$rw_prior_scale,config=cfg$config,curve_status='Bayesian reconstructed; between visits and before first observed visit model-derived using piecewise hazard; no extrapolation beyond 60 months',
          source_input_type=x$input_type[1],analysis_population=x$analysis_population[1],source_location=paste(unique(x$source_location),collapse='; '),
          stringsAsFactors=FALSE); ii <- ii+1
      }
      point_draws <- ex$risk
      if(is.null(dim(point_draws))) point_draws <- matrix(point_draws,ncol=nrow(x))
      ppc_rows <- list()
      for(k in seq_len(nrow(x))) {
        eta <- qlogis(pmin(pmax(point_draws[,k],1e-8),1-1e-8))
        yrep <- plogis(rnorm(length(eta),mean=eta,sd=x$logit_se_approx[k]))
        pred <- quantile(yrep,c(.025,.975),names=FALSE)
        ppc_rows[[k]] <- data.frame(time_months=x$time_months[k],observed_risk=x$risk[k],predictive_lower=pred[1],predictive_upper=pred[2],covered=x$risk[k]>=pred[1] & x$risk[k]<=pred[2])
      }
      pp <- do.call(rbind,ppc_rows)
      draw_store[[arm_id]] <- list(primary_draws=monthly,observed_ppc=pp)
      saveRDS(fit,file.path(outdir,paste0('trajectory_fit_',gsub('[^A-Za-z0-9]+','_',arm_id),'.rds')))
    } else {
      for(m in 1:60) {
        sens_rows[[jj]] <- data.frame(study_id=x$study_id[1],technique_arm_id=arm_id,technique_id=x$technique_id[1],
          procedure_as_reported=x$procedure_as_reported[1],time_months=m,config=cfg$config,rho=cfg$rho,rw_prior_scale=cfg$rw_prior_scale,
          posterior_median=smry[m,'median'],lower95=smry[m,'lower'],upper95=smry[m,'upper'],stringsAsFactors=FALSE); jj <- jj+1
      }
    }
    summ <- rstan::summary(fit,pars=c('sigma_rw','log_hazard_per_month','risk_monthly'))$summary
    sampler <- rstan::get_sampler_params(fit,inc_warmup=FALSE)
    divergences <- sum(vapply(sampler,function(a)sum(a[,'divergent__']),numeric(1)))
    depth_hits <- sum(vapply(sampler,function(a)sum(a[,'treedepth__']>=14),numeric(1)))
    diag_rows[[length(diag_rows)+1]] <- data.frame(study_id=x$study_id[1],technique_arm_id=arm_id,config=cfg$config,rho=cfg$rho,
      rw_prior_scale=cfg$rw_prior_scale,chains=4,iterations_per_chain=iter,warmup_per_chain=warmup,
      max_rhat=max(summ[,'Rhat'],na.rm=TRUE),min_rstan_n_eff=min(summ[,'n_eff'],na.rm=TRUE),divergences=divergences,
      max_treedepth_hits=depth_hits,ppc_marginal_95_coverage=if(primary) mean(pp$covered) else NA_real_,
      ppc_visits=if(primary) nrow(pp) else NA_integer_,stringsAsFactors=FALSE)
    cat('Finished',arm_id,cfg$config,'Rhat',round(max(summ[,'Rhat'],na.rm=TRUE),3),'divergences',divergences,'\n')
  }
}
write.csv(do.call(rbind,curve_rows),file.path(outdir,'trajectory_primary_curve.csv'),row.names=FALSE,fileEncoding='UTF-8')
write.csv(do.call(rbind,sens_rows),file.path(outdir,'trajectory_sensitivity_curves.csv'),row.names=FALSE,fileEncoding='UTF-8')
write.csv(do.call(rbind,diag_rows),file.path(outdir,'trajectory_diagnostics.csv'),row.names=FALSE,fileEncoding='UTF-8')
saveRDS(draw_store,file.path(outdir,'trajectory_primary_draws_and_ppc.rds'))
cat('Wrote primary trajectories:',length(curve_rows),'monthly cells; sensitivity cells:',length(sens_rows),'diagnostics:',length(diag_rows),'\n')

