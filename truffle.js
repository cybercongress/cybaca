const { toWei } = require('ethjs-unit');
const HDWalletProvider = require('truffle-hdwallet-provider');

const infuraConfig = require('./infura_deploy.json');

module.exports = {
    
    migrations_directory: "./migrations",
    
    networks: {
        infura: {
            provider() {
              return new HDWalletProvider(infuraConfig.privateKey, infuraConfig.infuraUrl);
            },
            from: infuraConfig.fromAddress,
            network_id: 4,
            gasPrice: toWei(10, 'gwei').toNumber(),
            gas: toWei(6, 'mwei').toNumber()
        },
        
        development: {
            host: "localhost",
            port: 8545,
            network_id: "5777"
        }
    },
    
    solc: {
        optimizer: {
            enabled: true,
            runs: 500
        }
    },
    
    mocha: {
        reporter: 'eth-gas-reporter',
        reporterOptions: {
            currency: 'USD',
            gasPrice: 10
        }
    }
};