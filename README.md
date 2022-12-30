# CP4D46WKC
CP4D 4.6 WKC Training

Importing the accelerator

To use this accelerator on Cloud Pak for Data v4.6.0.0, complete the following steps:

### Download the utilities-payment-risk-prediction-industry-accelerator.tar.gz file, 

    which is available on the https://github.com/IBM/Industry-Accelerators repository.

## Extract the contents of the package.

### Determine how you want to import the accelerator:

#### If your Cloud Pak for Data user account has Admin privileges, all components can be installed by following these steps:

From a command prompt, run the following command to extract the contents of the package:

     tar -xvf {TARFILENAME} 

Run the following command to navigate into the folder with the accelerator artefacts extracted from the tar.gz file.

    cd utilities-payment-risk-prediction-industry-accelerator 

Run one of the following commands to import the accelerator content into Cloud Pak for Data.

Example 1: Run the import in interactive mode. When prompted, enter the required information.

     ./import-accelerator-script.sh 

Example 2: For a list of all available options, including how to pass arguments to the import script, enter the command:

     ./import-accelerator-script.sh --help 

Example 3: Run the import passing arguments. The following command will import the accelerator into a project named "Utilities Payment Risk Prediction" and import categories and business terms into Watson Knowledge Catalog.

     ./import-accelerator-script.sh --hostname https://hostname:port --username username --password password --name "Utilities Payment Risk Prediction"

Example 4: Run the import passing additional arguments to publish the business glossary terms and run notebook jobs.

     ./import-accelerator-script.sh --hostname https://hostname:port --username username --password password --name "Utilities Payment Risk Prediction" --publish_glossary --run_jobs
     
     
## CP4D Cluster details

    https://cpd-cpd-instance.itzroks-0600009hxe-k2flw9-6ccd7f378ae819553d37d5f2ee142bd6-0000.eu-de.containers.appdomain.cloud
    
    user: admin
    password: passw0rd

## DB2 WH credentials

    Database: bludb
    Hostname or IP address: 54a2f15b-5c0f-46df-8954-7e38e612c2bd.c1ogj3sd0tgtu0lqde00.databases.appdomain.cloud
    Port: 32733
    Username: qsk67763
    Password: oPTiLLAldgPPESFP
