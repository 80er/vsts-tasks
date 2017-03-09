"use strict";

import * as path from "path";
import * as tl from "vsts-task-lib/task";
import * as constants from "./constants";
import * as definitions from "./definitions"

// provider for all template variables which are derived from task input(apart from azure subscription input which is read by AzureSpnVariablesProvider)
export default class TaskInputTemplateVariablesProvider implements definitions.ITemplateVariablesProvider {

    constructor() {
    }

    public register(packerHost: definitions.IPackerHost): void {
        packerHost.registerTemplateVariablesProvider(definitions.VariablesProviderTypes.TaskInput, this);
        tl.debug("registered task input variables provider");        
    }

    public getTemplateVariables(packerHost: definitions.IPackerHost): Map<string, string> {
        if(!!this._templateVariables) {
            return this._templateVariables;
        }

        // VM specific variables
        this._templateVariables = new Map<string, string>();
        var taskParameters = packerHost.getTaskParameters();
        this._templateVariables.set(constants.TemplateVariableResourceGroupName, taskParameters.resourceGroup);
        this._templateVariables.set(constants.TemplateVariableStorageAccountName, taskParameters.storageAccount);
        this._templateVariables.set(constants.TemplateVariableImagePublisherName, taskParameters.imagePublisher);
        this._templateVariables.set(constants.TemplateVariableImageOfferName, taskParameters.imageOffer);
        this._templateVariables.set(constants.TemplateVariableImageSkuName, taskParameters.imageSku);
        this._templateVariables.set(constants.TemplateVariableLocationName, taskParameters.location);

        var capturePrefix = tl.getVariable('release.releaseName') || tl.getVariable('build.buildnumber') || "vstscapture";
        this._templateVariables.set(constants.TemplateVariableCapturePrefixName, capturePrefix);        
        
        // user deployment script specific variables
        var deployScriptPath = taskParameters.deployScriptPath;
        var packagePath = taskParameters.packagePath;
        this._templateVariables.set(constants.TemplateVariableScriptPathName, deployScriptPath);
        this._templateVariables.set(constants.TemplateVariableScriptName, path.basename(deployScriptPath));
        this._templateVariables.set(constants.TemplateVariablePackagePathName, packagePath);
        this._templateVariables.set(constants.TemplateVariablePackageName, path.basename(packagePath));
        
        return this._templateVariables;
    }

    private _templateVariables: Map<string, string>;
}