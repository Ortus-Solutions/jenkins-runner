# Jenkins Runner

A simple utility for running a Jenkins job from CFML and optionally capturing the output

## Installation

Install the project via CommandBox like so:

```
install jenkins-runner
```

This module currenlty only works on Lucee because Adobe's tag-in-script syntax is dumb and I hate typing it.  If you want this to work in Adobe CF, please send a pull and will happily merge it :)

### Use as ColdBox Module
To use in ColdBox, provide the settings in your `config/Coldbox.cfc` in the `moduleSettings` struct like so:
```js
moduleSettings = {
  "jenkins-runner" : {
        username : 'myUser',
        password : getSystemSetting( 'JENKINS_PASSWORD' ),
        jenkinsAPIURL : 'http://jenkins.myserver.com:8080/'
  }
};
```

Then inject the jenkins runner, which is a singleton like so:
```js
propery name='JenkinsRunner' inject;
```
or
```js
var jenkingRunner = wirebox.getInstance( 'JenkinsRunner' );
```

### Use outside of ColdBox.
This module does not require ColdBox or WireBox to operate.  You can directly create an instance of the CFC and provide your own configuration.

```js
var jenkinsRunner = new modules.jenkins-runner.models.jenkinsRunner( 'usermame', 'password', 'http://jenkins.myserver.com:8080/' );
```

## Usage

To fire a job, you need the job name as it appears in the URL of the Jenkins site without the leading `job/`.

```js
 jenkinsRunner.run( 'Scheduled%20Jobs/job/Daily/job/TestJob/' );
 ```
 By default, this will return immediatley and the job will run asyncrnously.

### Build Parameters

For parameterized jobs, pass the parameters as a struct.

```js
jenkinsRunner.run(
    jobName = 'Scheduled%20Jobs/job/Daily/job/TestJob/',
    jobParameters = {
        "param1" : "value 1",
        "param2" : "value 2",
        "param3" : "value 3"
    }
);
 ```
### Return Build output

 You can block until the job is complete and get the full console output by specifying `returnOutput=true`.

 ```xml
<cfset jobOutput = jenkinsRunner.run(
    jobName = 'Scheduled%20Jobs/job/Daily/job/TestJob/',
    returnOutput = true
)>
<pre>
#jobOutput#
</pre>
 ```
### Stream Build Output

 You can also exceute the job and stream back the build output as it happens in real time.  Pass a `jobOutputUDF` to accept each chunch of text as it appears.

 Here is an example doing this inside a CommandBox task runer and flushing the outout to the console:

 ```js
jenkinsRunner.run(
    jobName = 'Scheduled%20Jobs/job/Daily/job/TestJob/',
    jobOutputUDF = (text)=>print.text(text).toConsole()
);
```

Here is an example of doing it from a CFM page.

```xml
Job output:
<pre>
Starting Job...
<cfflush>
<cfscript>
    function flusher( text ){
        echo( text );
        flush;
    }
    jenkinsRunner.run(
        jobName = 'Scheduled%20Jobs/job/Daily/job/TestJob/',
        jobOutputUDF = flusher
    );
</cfscript>
</pre>
```
*Note: Providing a `jobOutputUDF` will automatically enable `returnOutput`.*

### Timeout

The Jenkins runner will timeouit after 5 minute by default.  Change this timeout by passing a number of seconds to the `timeoutSeconds` argument.
```js
var jobOutput = jenkinsRunner.run(
    jobName = 'Scheduled%20Jobs/job/Daily/job/TestJob/',
    returnOutput = true,
    // wait up to 15 minutes
    timeout = 60 * 15
);
```

*Note: when executing from a web server, you will also need to extend your page request timeout as well.*