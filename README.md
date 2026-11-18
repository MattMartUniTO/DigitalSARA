# POP-SCOPE

**Pelvic Organ Prolapse: Bayesian Synthesis of Clinical Outcomes and Procedure Evidence**

POP-SCOPE is a calculator that organizes published outcomes after pelvic organ prolapse surgery. It displays estimates from selected studies and, when repeated results are available, reconstructed curves of cumulative failure. Each estimate remains linked to the operation, study population, outcome definition, and follow up reported by its source.

## Using the calculator

1. Enter age, body mass index, the available POP-Q measurements, and current smoking status. Complete levator avulsion is optional.
2. Select **Calculate** to view estimates for procedures and time points supported by the evidence.
3. Open the Curves panel to view supported trajectories. The All Curves panel displays all seven curves together.

The calculator uses published aggregate results. It does not contain individual trial records or local patient data.

## Patient profile scenarios

For supported estimates, the calculator can show an exploratory scenario based on published associations for body mass index, POP-Q Ba, age, and current smoking. Overall POP-Q stage is not used: its published association was imprecise and carries overlapping anatomical information with Ba. Other POP-Q points can be entered for clinical context, but they do not affect the calculation. An optional levator avulsion scenario applies evidence about anatomical recurrence to a clinical composite and should be interpreted separately.

These scenarios are not calibrated predictions for an individual patient. They do not estimate the effect of a procedure for a particular patient and do not rank operations. They are intended for research and clinical discussion, alongside clinical judgment.

## Reading the results

- The available estimates come from different studies and may use different definitions of failure. They should not be read as one common measure of recurrence.
- The seven curves are model reconstructions from repeated estimates reported by OPTIMAL, SUPeR, and Menefee et al. Each source used its own definition of clinical composite failure and its own patient group.
- Values between published assessment times are reconstructed by the model; they were not observed at every month. The all curves panel shows median lines without uncertainty bands.
- An uncertainty interval describes uncertainty in the estimate; it does not show the range of outcomes expected for an individual patient.

The calculator is an exploratory research tool. It has not been validated for individual clinical prediction or treatment selection and should not replace clinical judgment.

## Version and reproducibility

Calculator release **v1.0.1** uses the R38 literature model. Published aggregate inputs, distributed draws, R and Stan scripts, and the recorded browser checks are available in [reproducibility](reproducibility/README.md). The [versioned snapshot](https://github.com/MattMartUniTO/POP-SCOPE/tree/v1.0.1) can be [downloaded as a ZIP](https://github.com/MattMartUniTO/POP-SCOPE/archive/refs/tags/v1.0.1.zip). No clinical patient records are included.
