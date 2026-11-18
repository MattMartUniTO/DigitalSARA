# POP-SCOPE calculator v1.0.1

Release date: 18 November 2026. Underlying evidence/model: R38, 28 October 2026.

The calculator applies four SAVE-U associations (BMI, Ba, age and smoking). Global POP-Q stage is excluded from the profile shift. Levator avulsion is optional and transports an anatomical association to a clinical composite. Its source is Schulten et al., AJOG 2022, DOI 10.1016/j.ajog.2022.04.046, PDF page 8 and Figure 8. The earlier HTML reference to Yeung et al. was incorrect and has been replaced; the coefficient itself is unchanged.

## Distributed data

`calculator_data/app_data.json` is the metadata embedded in index.html, including all 16 fixed-horizon estimates, seven curves and five applied/optional coefficients. The four profile-eligible point estimates are both SAVE-U arms and both SAM arms. Other point estimates retain their source endpoint without profile shifts.

The two gzip files contain the exact Float32 draw arrays embedded in the HTML. There are 2,000 draws for each of seven series. The full monthly file has 60 columns per series; the compact file retains months 12, 24, 36 and 60. Within each series the matrix is stored in R column-major order: all draws for month 1, then all draws for month 2, and so on. The series order is in app_data.json. Decompress with standard gzip; read little-endian Float32. The fitted primary Stan models had 8,000 retained draws per series; the browser distribution uses a 2,000-draw subset. Fixed-horizon profile scenarios generate 8,000 Beta draws in JavaScript. Neither number should be confused with the 200,000 draws used for the manuscript's within-trial point contrasts.

## Source model scripts

The inputs and R/Stan scripts are copied from the R38 analysis package. With R 4.3.1 and rstan 2.32.7 available, run from the repository root:

```
Rscript reproducibility/model/fit_pointwise_model.R reproducibility
Rscript reproducibility/model/fit_trajectory_model.R reproducibility
```

These commands refit the literature models and write a new outputs directory. They do not regenerate individual clinical data. The HTML already contains its distributed draws and runs without R. A correction to the SAVE-U author label in the copied selection manifest replaces Schierlitz with Schulten; numeric inputs are unchanged. This package does not contain source full texts, complete raw MCMC fit objects, or Mauriziano patient records.

## Verification

`verification/verify_calculator.cjs` uses Playwright and Edge. With Playwright on the Node module path, run:

```
node reproducibility/verification/verify_calculator.cjs
```

The recorded run passed 48 checks, plus mobile width and seven-line overlay checks. It verifies reference-profile identity, exact individual odds multipliers with fixed coefficients, expected mean and SD of uncertain coefficients, inactive contextual POP-Q measurements and clearing inputs. `calculator_verification.json` records results and browser version. These are software checks, not clinical validation. The smoke test does not rerun R/Stan.

## Version and integrity

The annotated Git tag `v1.0.1` identifies this snapshot. The Git commit and SHA-256 manifest identify exact content. GitHub provides a downloadable source archive at the tag. No Zenodo or other archival DOI has been minted, and this release must not be described as having one. The Git archive is an identifiable snapshot; a separate archival repository deposit remains possible.

The .gitattributes file disables automatic newline conversion so that downloaded release files retain the exact bytes checked by SHA256SUMS.json.
