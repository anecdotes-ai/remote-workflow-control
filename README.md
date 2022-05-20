
# remote-workflow-control
A Github action that triggers a remote workflow and tracks down its exit status

In a multi git repository environment we have today, we sometimes face with the need to trigger a remote workflow from a running workflow when both are located in different repositories. Triggering a remote workflow is not a big deal, however waiting for a reliable exit status and building job dependencies based on that exit status - is not inherently supported in Github and requires some implementation effort on our end. This is due to the fact that when you submit a POST request to Github’s API to trigger a workflow, you get no output back. Ideally, one should have at least received the ‘Run ID’ of the triggered workflow, but that’s not the case. 

In this document I’ll describe how my solution is implemented by harnessing Github’s ‘artifacts’ feature to track a workflow’s exit code.For the sake of demonstration,  let’s assume I’m trying to trigger ‘workflow A’ from ‘workflow B’.

‘Workflow A’ YAML Configuration (the one being triggered)

    name: Deploy Env
    
    on:
      workflow_dispatch:
        inputs:
          trigger_uuid:
            description: 'the trigger UUIID for which we will create an artifact'
            required: false
    
    jobs:
      deploy-env:
        runs-on: ubuntu-latest
        steps:
        - name: Create Run UUID Artifact
          if: github.event.inputs.trigger_uuid != ''
          run: |
              echo $GITHUB_API_URL/repos/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID | \
                  tee /tmp/${{ github.event.inputs.trigger_uuid }}
        - name: Deploy an Environment
          run: ...
          
        - name: Upload UUID As An Artifact
          uses: actions/upload-artifact@v2
          if: ${{ always() && github.event.inputs.trigger_uuid != '' }}
          with:
            name: ${{ github.event.inputs.trigger_uuid }}
            path: /tmp/${{ github.event.inputs.trigger_uuid }} 

As you can see, we define an optional ‘trigger_uuid’ input for this workflow, which we’ll use when we remotely trigger this workflow.  In the ‘jobs’ section, the first step is to write the full URL of this workflow to a temp file. The file name is the value of ‘trigger_uuid’. We’ll later query this URL in ‘workflow2’ and gather the exit status of ‘workflow1’. We then proceed to execute as many steps as we’d like, but wrap up the workflow with the  ‘Upload UUID As An artifact' step. This would upload the temp file we created earlier on as an artifact of this workflow. Notice that this step would only run when 'trigger_uuid’ is given as input, so scheduled runs (if any) or manual runs will not be affected. 

‘Workflow B’ YAML Configuration (the one that triggers)

    name: Deploy and Test Env
    
    ...
    
    jobs:
      test-env:
        runs-on: ubuntu-latest
        steps:
          - name: Run Remote Workflow
            uses: anecdotes-ai/remote-workflow-control@latest
            with:
              github-auth-token: ${{ secrets.GITHUB_KEY }}
              workflow-org: 'anecdotes-ai'
              workflow-repo: 'api'
              workflow-yaml: 'deploy.yaml'
              workflow-branch: 'master'
              workflow-inputs: '{\"deploy_frontend\": true \"debug_mode\": false}'
              wait-timeout-in-minutes: '10'
              
          - name: Test Deployment
            run: ...

As you see, we’re simply calling the ‘remote-workflow-control’ Github action and provide it with arguments. 

So how does it actually work behind the scenes?

When we triggered ‘workflow A’, we provided a unique ID as an input.Once this workflow has been concluded (whether failure/success), the unique ID is uploaded as a Github artifact file. The file contains the URL of ‘workflow A’ RUN_ID.  During the ‘wait for status’ phase, we periodically query Github’s API for the existence of an artifact named after our unique ID. Once found (which indicates ‘workflow A’ has been completed), we download the artifact file and read the URL that’s stored in it. We then query that URL to gather the workflow’s exit status. Once read - the artifact is deleted. 

If you have any questions regarding this implementation, please don’t hesitate to ask. 
