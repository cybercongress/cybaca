const { toWei } = require('ethjs-unit');
const HDWalletProvider = require('truffle-hdwallet-provider');

const infuraConfigRinkeby = require('./infura_rinkeby_deploy.json');
const infuraConfigMainnet = require('./infura_main_deploy.json');

module.exports = {
    
    migrations_directory: "./migrations",
    
    networks: {
        infura_rinkeby: {
            provider() {
              return new HDWalletProvider(infuraConfigRinkeby.privateKey, infuraConfigRinkeby.infuraUrl);
            },
            from: infuraConfigRinkeby.fromAddress,
            network_id: 4,
            gasPrice: toWei(10, 'gwei').toNumber(),
            gas: toWei(6, 'mwei').toNumber()
        },
        
        infura_main: {
            provider() {
              return new HDWalletProvider(infuraConfigMainnet.privateKey, infuraConfigMainnet.infuraUrl);
            },
            from: infuraConfigMainnet.fromAddress,
            network_id: 0,
            gasPrice: toWei(50, 'gwei').toNumber(),
            gas: toWei(6, 'mwei').toNumber()
        },
        
        development: {
            host: "localhost",
            port: 7545,
            network_id: "5777"
        }
    },
    
    compilers: {
        solc: {
          version: "0.5.0",
          settings: {
            optimizer: {
              enabled: true,
              runs: 500
            },
            evmVersion: "byzantium"
          }
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