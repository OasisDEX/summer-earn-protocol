// spawnDevNet.js
const { exec } = require('child_process');
require('dotenv').config();

const spawnDevnet = () => {
    const templateSlug = process.env.TENDERLY_TEMPLATE_SLUG;
    const projectSlug = process.env.TENDERLY_PROJECT_SLUG;
    const account = process.env.TENDERLY_ACCOUNT;

    if (!templateSlug || !projectSlug || !account) {
        console.error('Please set TENDERLY_TEMPLATE_SLUG, TENDERLY_PROJECT_SLUG and TENDERLY_ACCOUNT in your .env file');
        process.exit(1);
    }

    const command = `tenderly devnet spawn-rpc --template ${templateSlug} --project ${projectSlug} --account ${account}`;

    exec(command, (error, stdout, stderr) => {
        if (error) {
            console.error(`Error executing command: ${error.message}`);
            return;
        }
        if (stderr) {
            console.error(`stderr: ${stderr}`);
            printRPCUrl(stderr.trim())
            return;
        }
        console.log(`stdout: ${stdout}`);

        printRPCUrl(stdout.trim())
    });


};

const printRPCUrl = (newDevNetUrl) => {
    console.log(`TENDERLY_VIRTUAL_TESTNET_RPC_URL=${newDevNetUrl}`);
}

spawnDevnet();
