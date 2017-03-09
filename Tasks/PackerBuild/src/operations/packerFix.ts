"use strict";

import * as path from "path";
import * as tl from "vsts-task-lib/task";
import packerHost from "../packerHost";

export function run(packerHost: packerHost): Q.Promise<any> {
    var command = packerHost.createPackerTool();
    command.arg("fix");

    // do not validate in fix. We will validate separately
    command.arg("-validate=false");
    command.arg(packerHost.getTemplateFileProvider().getTemplateFileLocation(packerHost));

    console.log(tl.loc("ExecutingPackerFix"));
    return packerHost.execTool(command);
}