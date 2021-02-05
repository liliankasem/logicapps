# Logic Apps v2

[![Build Status](https://dev.azure.com/logicappsdemo/Logic%20Apps%20v2%20Sample/_apis/build/status/classic/Classic%20-%20CI?branchName=main)](https://dev.azure.com/logicappsdemo/Logic%20Apps%20v2%20Sample/_build/latest?definitionId=3&branchName=main)

This repository contains a sample Logic App v2 project, with Azure deployment and pipeline examples.

- [Logic Apps v2](#logic-apps-v2)
  - [Prerequisites](#prerequisites)
  - [Local](#local)
    - [API Connections](#api-connections)
    - [VS Code](#vs-code)
    - [Docker](#docker)
  - [DevOps](#devops)
    - [ARM Deployment](#arm-deployment)
    - [Azure Pipelines](#azure-pipelines)
      - [IaC Pipeline](#iac-pipeline)
      - [PR Pipeline](#pr-pipeline)
      - [CI Pipeline](#ci-pipeline)
      - [CD Pipeline](#cd-pipeline)
    - [Pipeline Variables](#pipeline-variables)
      - [Variable Files](#variable-files)
  - [Known Issues & Limitations](#known-issues--limitations)
    - [Q & A](#q--a)

## Prerequisites

- Azure Subscription
- [Azure Storage Account or Emulator](https://docs.microsoft.com/azure/logic-apps/create-stateful-stateless-workflows-visual-studio-code#storage-requirements)
- [Visual Studio Code](https://code.visualstudio.com/)
- [Visual Studio Tools](https://docs.microsoft.com/azure/logic-apps/create-stateful-stateless-workflows-visual-studio-code#tools)
- [ARM Outputs Azure DevOps Task](https://marketplace.visualstudio.com/items?itemName=keesschollaart.arm-outputs)

## Local

To run the project locally, you can follow the [documentation provided by the Logic Apps team](https://docs.microsoft.com/azure/logic-apps/create-stateful-stateless-workflows-visual-studio-code#run-test-and-debug-locally).

### API Connections

This project uses the office 365 API connection. For you to run this project, you will need to generate a `connections.json` file. There are two ways you can do this,
you can either create a new API connection, or connect to a pre-deployed connection (i.e. you have already created an API connection in Azure, through an IaC pipeline or otherwise).

If you want to use a pre-deployed connection, provide the following variables in your `local.settings.json`:

> Read more about why you have to recreate the action [here](#known-issues--limitations).

```json
"WORKFLOWS_TENANT_ID": "",
"WORKFLOWS_SUBSCRIPTION_ID": "",
"WORKFLOWS_RESOURCE_GROUP_NAME": "",
"WORKFLOWS_LOCATION_NAME": "",
```

If you want to create a new connection, the above values will get populated for you when you create the connection in the designer.

Follow these steps:

1. Right-click on the `workflow.json` file (inside ExampleWorkflow/ folder)
2. Click `Open in designer`
3. Right-click on the office365 connection and click `Delete`
4. Add a new step
5. Select the Azure tab and search for `office365`
6. Select the `Office 365 Outlook` and search for `send email`
7. Select the `Send an email (V2)` action
8. Click `Sign in` and follow the process to authenticate the office 365 connection
9. Make sure to hit `Save`

Once complete, a `connection.json` file will be generated for you, and the `local.settings.json` should be updated to contain the key for the office365 connection. If you provided the
workflow variables mentioned above, the Logic App should connect to a pre-existing connection instead of creating a new one. You can always go back into the designer and change the connection.

> NOTE: When you recreate the `Send an email` action, the parameter used for the to address will be removed. If you want to parameterize this value, update the `workflow.json` file so that
> it uses app settings for the email address `To": "@appsetting('emailAddress')"`

### VS Code

- Open the project in VSCode
- Create or update the `local.settings.json` file and make sure it has the following variables:

  ```json
  {
    "IsEncrypted": false,
    "Values": {
      "FUNCTIONS_WORKER_RUNTIME": "dotnet",
      "AzureWebJobsStorage": "",
      "emailAddress": "",
      "office365-connectionKey": ""
    }
  }
  ```

  > You should be able to get the `office365-connectionKey` value by creating the API connection as explained [here](#api-connections).

- Navigate to the `Run` tab and hit the play icon to run the application
- Right-click on the `workflow.json` file and click `Overview`
- Here you should see a callback URL, you can use that to trigger your workflow

> If you're running on a Mac, you cannot use an emulator for the storage account and will have to point to a real account in Azure for now.

### Docker

Using docker, you can build and run using the following commands:

`docker build . -t local/logicappsample`

`docker run --env-file .env -p 8080:80 local/logicappsample`

You will need a .env file containing these variables:

```txt
AzureWebJobsStorage=
emailAddress=
office365-connectionKey=
```

Once your application is running:

- Get the master key from your storage account or emulator
  - [Documentation here](https://docs.microsoft.com/azure/logic-apps/create-stateful-stateless-workflows-visual-studio-code#get-callback-url-for-request-trigger)

- Call `listCallbackUrl` to get the workflow URL:

  `http://localhost:8080/runtime/webhooks/workflow/api/management/workflows/ExampleWorkflow/triggers/manual/listCallbackUrl?api-version=2020-05-01-preview&code=<MASTER KEY GOES HERE>`

- You can then use the workflow URL to trigger your Logic App

> NOTE: When using docker, I have noticed that the `host.json` (inside the storage account) is not created until a request is made to the logic app. So if you don't see a new folder with
> a `host.json` file, try just making a call to `listCallbackUrl` URl above without the master key then check your storage account again.

## DevOps

You can view a sample of this project's deployment in [Azure DevOps](https://dev.azure.com/logicappsdemo/Logic%20Apps%20v2%20Sample/_build?view=folders).

### ARM Deployment

The `.deploy` folder contains the ARM templates required to deploy all the required logic app resources.

- `connectors-template.json` deploys an office 365 connector
- classic/
  - `logicapp-template.json`
    - Windows logic app
    - App service plan
    - Storage account
- container/
  - `logicapp-template.json`
    - Linux logic app (container based deployment)
    - App service plan
    - Storage account
  - `acr-template.json`
    - Azure container registry (ACR)

### Azure Pipelines

The `.pipelines` folder contains examples of how to deploy both the container version and the normal version of the logic app.

#### IaC Pipeline

- Deploys the logic app and API connections
  - [Container version] also deploys ACR
- Publishes artifact for the connections output file

> Make sure you create and run this pipeline before any of the other pipelines. The CI pipeline needs the IaC pipeline to function as it will download the artifact that is published
> in order to make the `connections.json` file.

#### PR Pipeline

- [Classic version] Use dotnet task to build project
- [Container version] Build docker image

> Ideally, you also run unit tests here

#### CI Pipeline

- Downloads the API connections output file that was published by the IaC pipeline
- Uses the `.pipelines/scripts/Configure-Connections.ps1` script to replace the tokens in the `connections.devops.json` file to generate a `connections.json` file
- [Classic version]
  - Runs `dotnet publish` to generate zip of project
  - Publishes project zip as pipeline artifact
- [Container version]
  - Build and push docker file to ACR

> #### Decouple the CI pipeline from IaC
>
> Instead of publishing the ARM output for the connections in your IaC pipeline, you can use the `.pipelines/scripts/Generate-Connections.ps1` script
> which will generate a `connections.json` file using all the API connections deployed to a resource group. This way you can decouple the CI pipeline from the IaC pipeline.
> However, the `Generate-Connections.ps1` does *not* work for function app connectors.

#### CD Pipeline

- [Classic version]
  - Download CI pipeline artifact containing project zip
  - Use the Azure Functions task to deploy the project
- [Container version]
  - Use the Azure Functions container task to deploy the project (using the docker image that was published by the CI pipeline)

### Pipeline Variables

For both the classic and container deployment approach, you will need to supply a set of variables to make the deployments possible.

#### Variable Files

Under the `variables/` folder & in some pipeline files, you will need to fill in some variables:

```yml
# vars-iac
devServiceConnection: 'NAME OF AZURE SERVICE CONNECTION IN AZURE DEVOPS'

# vars-ci
projectId: 'ID OF AZURE DEVOPS PROJECT'
iacPipelineDefinitionId: 'ID OF THE IAC PIPELINE IN AZURE DEVOPS'

# cd-pipeline
toEmailAddress: 'EMAIL ADDRESS THE EXAMPLE WORKFLOW SHOULD EMAIL'
```

> NOTE: You can search for `TODO` to find all the values you need to replace.

You will need need to create a service connection for your Azure subscription for many of the pipeline tasks to work. [Follow this documentation to create your service connection](https://docs.microsoft.com/azure/devops/pipelines/library/connect-to-azure?view=azure-devops).

> The `azure_subscription` variable group can be removed if you clone this repo. It is being used to hold all the variables that we need to fill in to make the sample Azure
> DevOps pipeline run.

## Known Issues & Limitations

With Logic App v2 being in preview, there are some caveats to be aware of.

- You cannot parameterize values inside the `connection.json` file. You can replace an entire variable with an app settings parameter, but you cannot parameterize parts of a string. For example:

  - This works: `"someVariable": "@appsetting('exampleVariable')"`
  - This does *not* work: `"someVariable": "/subscriptions/@appsetting('subId')/resourceGroups/@appsetting('resourceGroup')/"`

- Similar to the note about the connections file, you also cannot parameterize the `workflow.json` file (you are able to do entire variables, but not partial like the example above).
  - Something worth noting: whilst I was able to use an app settings parameter for the email address in the ExampleWorkflow, when trying to do the same for items in the Event Grid trigger
    action (such as the topic, path and filter properties) - that did not work.

- [Azurite](https://github.com/Azure/Azurite) is not yet supported.

- There is currently a bug where generating a new `connections.json` file will update `.csproj` with another entry for the connections file, feel free to delete this new reference - you
  do not need to reference the connections file more than once.

### Q & A

Q: Why do I have to recreate the action that uses the API connection?

- A: Currently, whilst Logic Apps v2 is in preview, the designer does not allow you to select or create a new connection when a `connections.json` file does not already exist, the only way
  around this is to recreate the action that uses the connection.

Q: Why do I need to get a connection key to run locally?

- A: When running logic apps locally, the connection needs to use the 'Raw' authentication method for connections to work. When deploying to Azure, the authentication method needs to be `ManagedServiceIdentity`,
  this is why we have a tokenized `connections.devops.json` file that we use in our DevOps pipelines to deploy our logic app.
