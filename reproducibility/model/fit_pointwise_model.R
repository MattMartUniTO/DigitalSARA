args <- commandArgs(trailingOnly=TRUE)
root <- if (length(args)) normalizePath(args[1], winslash='/', mustWork=TRUE) else normalizePath(file.path(dirname(sub('--file=', '', commandArgs()[grep('--file=', commandArgs())][1])), '..'), winslash='/', mustWork=TRUE)
inp <- file.path(root, 'inputs')
out <- file.path(root, 'outputs')
dir.create(out, recursive=TRUE, showWarnings=FALSE)
counts <- read.csv(file.path(inp,'model_binomial.csv'), stringsAsFactors=FALSE, encoding='UTF-8', check.names=FALSE)
sens <- read.csv(file.path(inp,'sensitivity_binomial.csv'), stringsAsFactors=FALSE, encoding='UTF-8', check.names=FALSE)
set.seed(20261026)
posterior_one <- function(d, block_label) {
  d$events <- as.integer(d$events); d$denominator <- as.integer(d$denominator)
  a <- d$events + 0.5; b <- d$denominator - d$events + 0.5
  data.frame(observation_id=d$observation_id, study_id=d$study_id, cohort_linkage_id=d$cohort_linkage_id,
    pair_id=d$pair_id, arm_order=d$arm_order, technique_arm_id=d$technique_arm_id, technique_id=d$technique_id,
    procedure_as_reported=d$procedure_as_reported, endpoint_class=d$endpoint_class,
    endpoint_as_reported=d$endpoint_as_reported, event_label=d$event_label,
    events=d$events, denominator=d$denominator, time_months=d$time_months,
    analysis_population=d$analysis_population, estimand_type=d$estimand_type,
    analysis_block=block_label, posterior_median=qbeta(.5,a,b), lower95=qbeta(.025,a,b), upper95=qbeta(.975,a,b),
    prior='Beta(0.5, 0.5) Jeffreys prior', source_file=d$source_file, source_location=d$source_location,
    interpretation_limit=d$source_definition_or_caveat, stringsAsFactors=FALSE)
}
trajectory_inputs <- read.csv(file.path(inp,'trajectory_inputs.csv'), stringsAsFactors=FALSE, encoding='UTF-8', check.names=FALSE)
trajectory_studies <- unique(trajectory_inputs$study_id)
# Repeated cumulative outcomes enter only the longitudinal likelihood. Visit estimates are added from those same curve draws after fitting.
primary <- counts[counts$include_primary=='yes' & counts$analysis_block=='primary_pointwise_binomial' & !counts$study_id %in% trajectory_studies,,drop=FALSE]
variable <- counts[counts$analysis_block=='descriptive_variable_followup',,drop=FALSE]
extension <- counts[counts$analysis_block=='linked_extension_descriptive',,drop=FALSE]
main_results <- posterior_one(primary, 'primary_pointwise_marginal')
desc_results <- posterior_one(variable, 'descriptive_variable_followup')
extension_results <- posterior_one(extension, 'linked_extension_descriptive_posterior_among_responders')
sens_results <- posterior_one(sens, 'sensitivity_only')
write.csv(main_results,file.path(out,'pointwise_model_results.csv'),row.names=FALSE,fileEncoding='UTF-8')
write.csv(desc_results,file.path(out,'descriptive_proportions.csv'),row.names=FALSE,fileEncoding='UTF-8')
write.csv(extension_results,file.path(out,'linked_extension_results.csv'),row.names=FALSE,fileEncoding='UTF-8')
write.csv(sens_results,file.path(out,'sensitivity_results.csv'),row.names=FALSE,fileEncoding='UTF-8')
# Pairwise posterior risk differences are calculated only within one selected RCT, endpoint, visit and analysis population.
all_for_pairs <- rbind(main_results, desc_results)
pairs <- list(); k <- 1
for (pid in unique(all_for_pairs$pair_id)) {
  g <- all_for_pairs[all_for_pairs$pair_id==pid,,drop=FALSE]
  g <- g[order(as.numeric(g$arm_order)),,drop=FALSE]
  if (nrow(g)!=2 || g$event_label[1]!=g$event_label[2]) next
  a1 <- g$events[1]+0.5; b1 <- g$denominator[1]-g$events[1]+0.5
  a2 <- g$events[2]+0.5; b2 <- g$denominator[2]-g$events[2]+0.5
  p1 <- rbeta(200000,a1,b1); p2 <- rbeta(200000,a2,b2); rd <- p1-p2
  pairs[[k]] <- data.frame(pair_id=pid,study_id=g$study_id[1],endpoint_class=g$endpoint_class[1],
    endpoint_as_reported=g$endpoint_as_reported[1],time_months=g$time_months[1],analysis_population=g$analysis_population[1],
    arm1=g$procedure_as_reported[1],arm2=g$procedure_as_reported[2],event_label=g$event_label[1],
    arm1_events=g$events[1],arm1_n=g$denominator[1],arm2_events=g$events[2],arm2_n=g$denominator[2],
    posterior_RD_median=median(rd),lower95=unname(quantile(rd,.025)),upper95=unname(quantile(rd,.975)),
    interpretation='Posterior risk/proportion difference, arm 1 minus arm 2; source-specific only. No across-trial pooling.',
    stringsAsFactors=FALSE)
  k <- k+1
}
pair_df <- if(length(pairs)) do.call(rbind,pairs) else data.frame()
write.csv(pair_df,file.path(out,'within_trial_contrasts.csv'),row.names=FALSE,fileEncoding='UTF-8')
cat('Primary pointwise binomial rows:',nrow(main_results),'\n')
cat('Descriptive variable-follow-up proportions:',nrow(desc_results),'\n')
cat('Linked-extension responder-only descriptive posteriors:',nrow(extension_results),'\n')
cat('Sensitivity-only cells:',nrow(sens_results),'\n')
cat('Within-trial, matched-cell contrasts:',nrow(pair_df),'\n')



