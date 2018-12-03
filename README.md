## cybercon0 web3 dapp

### Bootstrap
```
npm i
```

### Tests
```
ganache-cli -p 8545 -a 250 -e 100
```
Note: tests pass for commit 1563874b1fc242a99228c868792f5869c4a38913, please checkout

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
