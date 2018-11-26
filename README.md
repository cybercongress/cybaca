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

#### Auction 
##### buyTicket: 
```
1. Anybody may buy ticket one time from address if tickets available.
2. Need to send current price.
3. Take CC0 ERC721 token.
2. If all tickets will bough before event start, end price will be reminded for future overbids returns .
3. If all tickets will bough before event start, timestamp will be reminded for future speakers rewards calculation.
```

#### Talk Application
##### applyForTalk
```
1. Anybody may apply for talk, but less than 32 proposals.
2. Shoud provide deposit more or equal than minimal speaker deposit.
```

##### acceptTalk
```
1. Organizer accepts interested talk .
2. But no more than speakers slots.
```

##### declineTalk
```
1. Organizer decline non-interested talk.
2. Send deposit back to applier.
```

#### Talk Deposit Self Return
##### checkMissedTalk
```
1. If talk was not checked for different reasons (missed, no more slots, etc) by organizer, 
than applier or organizer may decline talk and transfer deposit back to applier.
```

#### CheckIn, Conference 
##### checkinSpeaker
```
1. Organizer checkins accepted speakers and mint CCO tokens for them. 
```

#### Distribution 
##### distributeOverbids
```
1. Anybody may call this method and send all overbid value back to members.
2. Caller takes 1 ETH reward.
```

##### distributeRewards
```
1. Anybody may call this method and send reward/profit for speakers and organizer.
2. May be called only after distributeBids().
3. Caller takes 1 ETH reward.
4. Speakers reward linked to last sold ticket. Goes down from 80(start auction) to 20(start event).
```

