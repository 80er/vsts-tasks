import msRestAzure = require('./azure-arm-common');
import tl = require('vsts-task-lib/task');
import util = require('util');
import webClient = require('./webClient');
import Q = require('q');
import { ToError } from './AzureServiceClient';
import { WebJob, SiteExtension } from './azureModels';
export class KuduServiceManagementClient {
    private _scmUri;
    private _accesssToken: string;

    constructor(scmUri: string, accessToken: string) {
        this._accesssToken = accessToken;
        this._scmUri = scmUri;
    }

    public async beginRequest(request: webClient.WebRequest, reqOptions?: webClient.WebRequestOptions): Promise<webClient.WebResponse> {
        request.headers = request.headers || {};
        request.headers["Authorization"] = "Basic " + this._accesssToken;
        request.headers['Content-Type'] = 'application/json; charset=utf-8';
        var options: webClient.WebRequestOptions = {
            retryIntervalInSeconds: reqOptions && reqOptions.retryIntervalInSeconds ? reqOptions.retryIntervalInSeconds :  10,
            retryCount: reqOptions && reqOptions.retryCount ? reqOptions.retryCount : 6,
            retriableErrorCodes: reqOptions && reqOptions.retriableErrorCodes ? reqOptions.retriableErrorCodes : ["ETIMEDOUT"],
            retriableStatusCodes: reqOptions && reqOptions.retriableStatusCodes ? reqOptions.retriableStatusCodes :  [409, 500, 502, 503, 504]
        };
        
        var httpResponse = webClient.sendRequest(request, options);
        return httpResponse;
    }

    public getRequestUri(uriFormat: string) {
        uriFormat = uriFormat[0] == "/" ? uriFormat : "/" + uriFormat;
        return this._scmUri + uriFormat;
    }

    public getScmUri(): string {
        return this._scmUri;
    }
}

export class Kudu {
    private _client: KuduServiceManagementClient;

    constructor(scmUri: string, username: string, password: string) {
        var base64EncodedCredential = (new Buffer(username + ':' + password).toString('base64'));
        this._client = new KuduServiceManagementClient(scmUri, base64EncodedCredential);
    }

    public async updateDeployment(requestBody: any): Promise<any> {
        var httpRequest = new webClient.WebRequest();
        httpRequest.method = 'PUT';
        httpRequest.body = JSON.stringify(requestBody);
        httpRequest.uri = this._client.getRequestUri(`/api/deployments/${requestBody.id}`);

        try {
            var response = await this._client.beginRequest(httpRequest);
            tl.debug(`updateDeployment. Data: ${JSON.stringify(response)}`);
            if(response.statusCode == 200) {
                console.log(tl.loc("Successfullyupdateddeploymenthistory", response.body.url));
                return response.body.id;
            }

            throw response;
        }
        catch(error) {
            throw Error(tl.loc('FailedToUpdateDeploymentHistory', this._getFormattedError(error)));
        }
    }

    public async getContinuousJobs(): Promise<Array<WebJob>>{
        var httpRequest = new webClient.WebRequest();
        httpRequest.method = 'GET';
        httpRequest.uri = this._client.getRequestUri(`/api/continuouswebjobs`);
        try {
            var response = await this._client.beginRequest(httpRequest);
            tl.debug(`getContinuousJobs. Data: ${JSON.stringify(response)}`);
            if(response.statusCode == 200) {
                return response.body as Array<WebJob>;
            }

            throw response;
        }
        catch(error) {
            throw Error(tl.loc('FailedToGetContinuousWebJobs', this._getFormattedError(error)))
        }
    }

    public async startContinuousWebJob(jobName: string): Promise<WebJob> {
        console.log(tl.loc('StartingWebJob', jobName));
        var httpRequest = new webClient.WebRequest();
        httpRequest.method = 'POST';
        httpRequest.uri = this._client.getRequestUri(`/api/continuouswebjobs/${jobName}/start`);

        try {
            var response = await this._client.beginRequest(httpRequest);
            tl.debug(`startContinuousWebJob. Data: ${JSON.stringify(response)}`);
            if(response.statusCode == 200) {
                console.log(tl.loc('StartedWebJob', jobName));
                return response.body as WebJob;
            }

            throw response;
        }
        catch(error) {
            throw Error(tl.loc('FailedToStartContinuousWebJob', jobName, this._getFormattedError(error)));
        }
    }

    public async stopContinuousWebJob(jobName: string): Promise<WebJob> {
        console.log(tl.loc('StoppingWebJob', jobName));
        var httpRequest = new webClient.WebRequest();
        httpRequest.method = 'POST';
        httpRequest.uri = this._client.getRequestUri(`/api/continuouswebjobs/${jobName}/stop`);

        try {
            var response = await this._client.beginRequest(httpRequest);
            tl.debug(`stopContinuousWebJob. Data: ${JSON.stringify(response)}`);
            if(response.statusCode == 200) {
                console.log(tl.loc('StoppedWebJob', jobName));
                return response.body as WebJob;
            }

            throw response;
        }
        catch(error) {
            throw Error(tl.loc('FailedToStopContinuousWebJob', jobName, this._getFormattedError(error)));
        }
    }

    public async installSiteExtension(extensionID: string): Promise<SiteExtension> {
        console.log(tl.loc("InstallingSiteExtension", extensionID));
        var httpRequest = new webClient.WebRequest();
        httpRequest.method = 'PUT';
        httpRequest.uri = this._client.getRequestUri(`/api/siteextensions/${extensionID}`);
        try {
            var response = await this._client.beginRequest(httpRequest);
            tl.debug(`installSiteExtension. Data: ${JSON.stringify(response)}`);
            if(response.statusCode == 200) {
                console.log(tl.loc("SiteExtensionInstalled", extensionID));
                return response.body;
            }

            throw response;
        }
        catch(error) {
            throw Error(tl.loc('FailedToInstallSiteExtension', extensionID, this._getFormattedError(error)))
        }
    }

    public async getSiteExtensions(): Promise<Array<SiteExtension>> {
        var httpRequest = new webClient.WebRequest();
        httpRequest.method = 'GET';
        httpRequest.uri = this._client.getRequestUri(`/api/siteextensions`);
        try {
            var response = await this._client.beginRequest(httpRequest);
            tl.debug(`getSiteExtensions. Data: ${JSON.stringify(response)}`);
            if(response.statusCode == 200) {
                return response.body as Array<SiteExtension>;
            }

            throw response;
        }
        catch(error) {
            throw Error(tl.loc('FailedToGetSiteExtensions', this._getFormattedError(error)))
        }
    }

    public async getProcess(processID: number) {
        var httpRequest = new webClient.WebRequest();
        httpRequest.method = 'GET';
        httpRequest.uri = this._client.getRequestUri(`/api/processes/${processID}`);
        try {
            var response = await this._client.beginRequest(httpRequest);
            tl.debug(`getProcess. status code: ${response.statusCode} - ${response.statusMessage}`);
            if(response.statusCode == 200) {
                return response.body;
            }

            throw response;
        }
        catch(error) {
            throw Error(tl.loc('FailedToGetProcess', this._getFormattedError(error)))
        }
    }

    public async killProcess(processID: number) {
        var httpRequest = new webClient.WebRequest();
        httpRequest.method = 'DELETE';
        httpRequest.uri = this._client.getRequestUri(`/api/processes/${processID}`);
        try {
            var response = await this._client.beginRequest(httpRequest, {
                retriableErrorCodes: ["ETIMEDOUT"],
                retriableStatusCodes: [503],
                retryCount: 1,
                retryIntervalInSeconds: 5
            });
            tl.debug(`killProcess. Data: ${JSON.stringify(response)}`);
            if(response.statusCode == 502) {
                tl.debug(`Killed Process ${processID}`);
                return;
            }

            throw response;
        }
        catch(error) {
            throw Error(tl.loc('FailedToKillProcess', this._getFormattedError(error)))
        }
    }

    private _getFormattedError(error: any) {
        if(error && error.statusCode) {
            return `${error.statusMessage} (CODE: ${error.statusCode})`;
        }
        else if(error && error.message) {
            if(error.statusCode) {
                error.message = `${typeof error.message.valueOf() == 'string' ? error.message : error.message.Code + " - " + error.message.Message } (CODE: ${error.statusCode})`
            }

            return error.message;
        }

        return error;
    }
}