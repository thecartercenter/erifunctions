# erifunctions, Founding Vision

> This is the original founding brief for the erifunctions data system, written by an
> epidemiologist on the ERI team. It is the source-of-truth for *user intent* behind the package and the V2
> roadmap. The architectural questions it raises (the "Some Questions" section) are resolved
> in the [ADRs](adr/); the development plan derived from it lives in [`roadmap.md`](roadmap.md).
> Preserved here (moved out of the gitignored `sandbox/`) so the strategy travels with the repo.

---

# Background

I am a computational epidemiologist at The Carter Center (TCC) working in the health programs in disease eradication. I've written this code base where I've aggregated various functions and SOPs for data analysts (DA) and epidemiologists (Epi) into processes but now I need to refactor this to be a fully functional system for use by those two primary end users. I want you to use the functions within the codebase as the api to interact with the Azure and other microsoft resources. If you find something missing, it is likely that the users would need it too so we can develop it. I'm going to describe key responsibilities and processes for each of these users. The goal is for helper functions, vignettes, guides and reports from this codebase to be used to streamline and simplify the work of the DAs and the epis. Other actors who may not directly use the system but are key parts of the office are associate directors (ADs - they are program managers for countries / regions) and country representatives (program managers that are country specific).

The reason this repository and data system is so fragmented right now is due to project driven development rather than complete organizational development. Historically TCC has hired contractors to build out small pieces of a data collection or processing system (hsp-mal and the other things in the 'projects' blob). I am working to build a centralized data management system and repository that works for DAs and epis across projects. The primary unit of work is the "country". DAs, Epis, ADs all have specific countrys that they are in charge of and work with. Within each country we can have a variety of disease we work with. Each disease line can have different funders and reporting requirements. I am in charge of Haiti, Dominican Republic, Uganda and OEPA. I want to build a centralized system that can help my DAs and epis manage and work with the data from these locations. Eventually I want to be able to expand this to provide support for other epis / countries / diseases.

I'm building the plane while I'm flying it. I need a good way to keep track of the overall vision and development while keeping on building it and not letting long development sessions lose context and create local solutions for global issues. Happy to take any recommendations on the best way to deal with this.

# Your Task
I want you to go into ultraplan mode and evaluate various ways to do this correctly. Go through multiple rounds of questions to try to narrow this down further before we finish the plans and try to poke holes in what I'm trying to build.

# Design principles
- Whatever we build needs to be of maximum utility to data analysts and epidemiologists. They need to be able to reliably use this system to drive the data processing and interact with the data outputs. Think of it as a suite of tools or an API built specifically to deal with TCC health data.
- Key usage will be as an R package loaded through install_github, not load_all() within a repo. All the functions and any necessary authentication need to be able to work with interactive browser authentication for the users.
- This will need to be a mature set of tools that the DAs and epis will use for interaction with the data system. I don't want them to have to continuously edit the code base. They may fine tune functions or add in new error checks but generally speaking, these are not software developers.
- Consider this system an API to interact with these new TCC data systems. We want to "dogfood" our process meaning that we use the same tools we're building to then access the system. The idea is that we find other features or helpers we might need to continue to improve this interaction.
- Nobody is currently using these tools yet so we're okay making breaking changes or large systems changes.
- Follow best practices in software development, documentation, usability and security.
- We will build the system primarily in R but if there are other languages or processes that you'd recommend I'm happy to take input. We are using R because it is something that the DAs and epis are used to. Visualizations / processing can be done in other languages if needed but we should aim for R.
- TCC uses many systems so I want the Azure data store to play the role of a central repository. This is especially useful when we want dashboards or ArcGIS to use the space as a reference for data. We may, for example, create a new spatial file representing an evaulation area consisting of multiple districts. I want to be able to store this in the spatial section of azure and call it up through our system but also have it available through ArcGIS.
- All the helper functions need to be well organized and straight forward for DAs epis to use.
- I have reference files for all these data inputs and outputs. Rather than providing all of these at once I want to give you the opportunity to ask for them when they're needed so we don't rely on long context windows.

# Users
## Data Analysts
### Description
They usually have masters in public health and have some experience with SAS and R. They are very capable and able to follow training and documentation on how to run systems. We'll need to provide all of this as part of the system we develop. I'm going to provide you details about their tasks with as much detail as possible.
### Tasks
#### Load CMR data
- ADs or country representatives receive data in an email from the countries. The country team here can be external ministry of health or internal carter center country teams. In either case, they will not need access to these systems.
- ADs share the data with DAs. Usually through email but sometimes by uploading them to Sharepoint.
- DAs do a quick visual review of the data and then upload the Excel files into 'projects' blob in 'eridev'.
- Zack, a contractor, has built out the processing system in the repos I've shared with you (hsp-mal and others) which processes the excel data into final formats (in 'intermediate') and into formats that can ge ready by Power BI dashboards.
- Currently the processing often fails or throws errors that Zack has to fix or provide feedback for that the DAs then go and clean and re-upload.
- Some data quality checks are delayed until they hit the dashboard.
##### Notes
- The currently "ingest" function should do some of the cleaning and dq checks but then follow the existing stream where it places a cleaned excel sheet in 'projects' and then maintains a similar cleaned dataset in 'data'. If the data from 'intermediate' in 'projects' looks the same at the centralized database we have in 'data' then we can slowly phase out the work that is happening in 'hsp-mal'.
#### Load malaria surveillance data
- Senior country representative receives the data from the country and then either uploads it to Sharepoint or emails it to the DA.
- DAs do a quick visual review of the data and then upload the Excel files into the relevant section in the 'projects' blob in 'eridev'.
- A GHA process (similar to what Zack runs above) does some review and analysis. Cleaned data are dumped in 'intermediate' and then data for a powerBI dashboard are also output.
- DAs review the data in the dashboard or the GHA process hits an error and Zack needs to go in and check where it failed.
- Let me know if there is a good way for me to share the power bi data, again, the goal is to eventually move away from powerbi and use quarto reports or something else that you might recommend.
#### Process OEPA data
- ADs receive data on oncho treatments in Brazil and Venezuela in the yanomami region
- DAs receive data from ADs and then store and manually aggregate the data. I can provide you examples of what these data inputs and outputs look like so far when we get to that step.
#### Provide initial analytic products for epi QC
- There are numerous articles and products created by TCC such as funding reports and publications. ADs will present statements like "The final 2025 treatment data for the Uganda program were X, achieving X% of the treatment target. The program also delivered X treatments for schistosomiasis in X RB co-endemic districts, reaching X% of the targeted eligible population. As of May 2026, the MOH, with support from TCC, conducted RB MDA in the five districts of Madi Mid-North, with treatment data pending." which the DAs will have to enter initial data into and then have Epis QC before going back to the ADs.
#### Generate figures for proceedings or other outputs
- In a similar theme as the task above, DAs will often be asked to generate maps or figures for reports or publications. We want to build helper functions that will help them quickly analyze, verify and respond to this.
- This can also include regularly produced outputs like reports for SIL (a reporting requirement), Boart of Trustee reports and Eye of the Eagle articles. (I can provide examples of all of these later as a reference). Remember, we're not trying to regenerate those reportly completely but making the lookup and QC job of data analysts a lot easier.
#### Create ODK forms for surveys
- DAs will receive a protocol and example surveys from Epis
- They will polish the survey xlsform through multiple rounds of development
- They upload the XLS form into ODK and begin testing the system
- They pilot the form and ensure that everything is working well
- They load all users and manage access / submissions in the form.
#### Monitor the deployment of surveys in ODK and fix errors
- DAs develop a PowerBI dashboard to view the progress of the survey. This keeps track of key indicators such as # of surveys conducted, age range of respondents, location of survey, a map of survey completion, number of positives and other important metrics, keeping track of errors or data quality issues, keeping track of open response fields where surveyors can provide responses.
- As data collection begins they review and manage the data daily and provide feedback
- For any data entry errors, they speak with the supervisors and edit the data directly in ODK (need a better way to keep track of these manual edits)
##### Notes
- perhaps the DAs could input cleaning code into the analytic process so that they data are cleaned before they hit the dasboard as issues come up but they remain raw in the original dataset? Happy to take input.
#### Pre-process the ODK data into analytic datasets and create reports
- After a study is finished, the DA (or sometimes the Epi), take the first stab at extracting the data, cleaning, matching data across forms and creating a final analytic dataset that will be used for publications. These final tables are stored in Sharepoint and a report is created.
#### Perform QC on data and provide feedback to countries
- DAs will regularly review the data that are being received and email back to country teams to specify errors and issues in the data that are being shared.
#### Perform ad-hoc data requests
- DAs will often be asked to quickly look up metrics or interest or produce figures for presentations.
#### Review errors and logs for troubleshooting
- DAs need a way to easily look at a backlog of errors / logs and process them while keeping track of all the work that they've done.
#### Onboarding additional datasets
- indoor residual spraying is not part of our regular surveillance but it is necessary for a new analysis we're conducting. We need a way to add this data (belongs to a country and disease) without upending our entire centrlalized system.
## Epidemiologists
### Description
These are PhD scientists who guide the research and development of the disease eradication program at Carter Cetner. They manage DAs and guide the development of studies and protocols. They are able to use R but some may be rusty and will need lots of documentation and guidance. They will also need to be able to do all of the data processing and management tasks that the DAs conduct.
### Tasks
#### Conduct Research
- Much of the research will be driven by the outputs of the centralized surveillance / CMR data or through the studies conducted in the ODK form.
- Epis will often have extra or secondary data that will need to be added for analysis. This will often need to be referred to for reporting later but will also need to be tracked / updated for their specific research.
- once all data are loaded they will need to be tracked for version with specific tags created for data versions that are linked to publications so analyses can be reproduced.
- Epis will develop code for analysis and we need a system or process to organize these. Maybe we run their analysis in a new repo under a TCC research repo and use erifunctions to do the analysis?
- Epis will store / stage data, pre-process it to be relevant to their existing scope and then being performing analysis.
- Analytic outputs will often be figures, tables, text that will need to be staged somehow.
- Analyses will eventually need to produce presentations and publications. We should think about how this can be most easily shared / tracked. Currently TCC just uses Word with version to control publications.
#### Quality control of outputs
- look through the work that the DAs have conducted and verify that Epis calculate the same metrics / figures.
#### Quick one off analyses
- You've seen my "one_off_analyses" folder, but Epis are often asked to do quick analytic tasks ranging from figure creation to analyses.

# Piloting
- There are new CMR data expected on June 10th and new malaria surveillance data expected later this month. We should build the system so that we can test out some of the key DA tasks by trying out loading the new data and seeing what happens.
- There is a new ODK form being created for a survey in Uganda. Great opportunity to try out new dashboards and reporting. This will start in the next few weeks.
- There is an existing research project 'dr_irs.R' where we are conducting an analysis on the impact of indoor residual spraying on malaria incidendce in the DR. We are using an interrupted time series analysis. For this research I've had to digitize IRS data (which are not routinely reported) and matched that with malaria incidence data to calculate impact. We can work through this example to get even more feedback.

# Some Questions
- Should I break this up into a set of interdependent packages? eriauth, eriresearch, erianalyst, erifunctions etc. I can see the benefit of having everything in one package but am worried that the sheer number of functions will be overwhelming. How should I think about this given the use cases I've described above?
- Are there other things we could be doing with Azure storage to better complete our tasks?
- Should we consider using a more formal database for our final datasets or is an Azure based file storage system with good guardrails fine here?
- In the DA workflow, does it make more sense for them to pull specific data down and then process it through helper functions or have helper function directly pull and process the data? I'm leaning towards the former just so that every function doesn't require a similar data download.
- Would it be useful to have some sort or memory or agent that remembers this higher level design process and ensures that it is being followed or updated at each step?
