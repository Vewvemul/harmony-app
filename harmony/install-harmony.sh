const fs = require('fs');
const child_process = require('child_process');
const path = require('path');

const isWindows = process.platform === 'win32';
const windowLocalCurlFile = path.normalize('C:/Windows/System32/curl.exe');

const midwayCookieLocation = path.join(isWindows ? process.env.USERPROFILE : process.env.HOME, '/.midway/cookie');
const curl = process.env.HARMONY_CURL || (isWindows ? windowLocalCurlFile : '/usr/bin/curl');

function cyan(message) {
    console.log(`\x1b[36m${message}\x1b[0m`);
}

function getNodeMajorVersion() {
    try {
        const version = process.version.slice(1); // trim the 'v' at the start
        const parts = version.split('.');
        return Number(parts[0]);
    } catch (e) {
        throw new Error('Unable to get NodeJS version. Please confirm that NodeJS is installed correctly. Cause: ', e);
    }
}

function getNpmMajorVersion() {
    try {
        const fullVersion = child_process.execSync('npm -v').toString();
        const parts = fullVersion.split(".");
        return Number(parts[0]);
    } catch (e) {
        throw new Error('Unable to get npm version. Please confirm that NPM is installed correctly. Cause: ', e);
    }
}

try {
    fs.accessSync(curl, fs.constants.X_OK);
} catch (e) {
    console.error(`Curl cannot be found or executed at ${curl}. Verify that it is installed at the correct location or set the environment variable HARMONY_CURL to a custom location.`);
    process.exit(1);
}

try {
    const MIN_NODE_VERSION = 14;
    const nodeVersion = getNodeMajorVersion();
    if (nodeVersion < MIN_NODE_VERSION) {
        console.log(`The NodeJS version you have installed (${process.version}) is not supported. Please update to version ${MIN_NODE_VERSION} or higher, and try installing Harmony CLI again.`);
        process.exit(1);
    }
} catch (e) {
    console.error("ERROR: " + e.message);
    process.exit(1);
}

try {
    const mwinitOutput = child_process.execSync(`mwinit -l`, {stdio: ['ignore', 'pipe', 'ignore']}).toString();
    if (mwinitOutput.trim().length === 0) {
        console.log("You currently don't have any Midway cookies, which are required for running these commands. Please run \"mwinit\" (or mwinit -o from a Linux machine) and try again.");
        process.exit(1);
    }
} catch (e) {
    // mwinit returns 12 when the credentials are expired (though this doesn't seem to always work)
    // https://code.amazon.com/packages/MidwayInit/blobs/d3c6632b00a530dc34623066fdd46dcebd85aca1/--/main.cpp#L344-L345
    if (e.status == 12) {
        console.log('Your Midway credentials, which are required for running these commands, have expired. Please run "mwinit" (or mwinit -o from a Linux machine) and try again.');
        process.exit(1);
    }
}

const insecureFlag = isWindows ? ' --insecure ' : ' ';
const command = `${curl} -u : -s -b ${midwayCookieLocation} -c ${midwayCookieLocation}${insecureFlag}--anyauth -L "https://us-east-1.api.harmony.a2z.com/v1/sso/npm-config"`;
const npmConfigResult = child_process.execSync(command).toString();
const configs = [];

try {
    const npmConfig = JSON.parse(npmConfigResult);

    if (npmConfig.status === 'error') {
        throw npmConfig;
    }
    const npmMajorVersion = getNpmMajorVersion();
    for (let prop in npmConfig) {
        if (prop === 'always-auth' && npmMajorVersion > 6) {
            // Versions after 6 throw an error if you try to set unknown properties, 
            // and "always-auth" has been removed.
            continue;
        }
        configs.push(`npm config set ${prop} ${npmConfig[prop]}`);
    }
} catch (e) {
    if ((e.status === 'error' && e.message === 'Unauthenticated')) {
        console.log('Looks like you don\'t have a valid Midway session. Please run "mwinit" (or mwinit -o from a Linux machine) and try again.');
    } else {
        console.log('Sorry, something went wrong. Please try again in a few moments or cut us a ticket if the problem persists: https://t.corp.amazon.com/create/quicklink/Q001177917');
    }
    process.exit(1);
}

child_process.execSync(configs.join(' && ')).toString();
cyan('Successfully configured NPM to use CodeArtifact\'s internal "shared" repo...');

child_process.execSync(`npm install -g @amzn/harmony-cli`, {stdio: 'inherit'});

cyan('\nHarmony CLI installed and ready to rock-n-roll! 🎵 𝄞 🎸 𝄫 🎷🎶 🎻');
cyan('\n👉 Try "harmony app create" or follow our tutorial at https://console.harmony.a2z.com/docs/tutorials.html');