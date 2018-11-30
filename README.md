## cybercon0 web3 dapp

### Bootstrap
```
npm i
```

### Tests
```
ganache-cli -p 8545 -a 250 -e 100
```

### Migration
```
truffle migrate --network development --reset
```

### Code for verification
```
truffle-flattener contracts/Cybercon.sol > cybercon0_full.sol
```

### Event Flow 
![eventflow](docs/eventflow.png)

### Gas Usage 
![gas_usage](docs/gas_usage.png)
