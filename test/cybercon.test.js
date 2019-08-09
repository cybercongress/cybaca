const { getRandomString, getRandomInt } = require('./helpers/helpers')
const { BN, time } = require('openzeppelin-test-helpers');

const chai = require("chai");
const bnChai = require("bn-chai");
const expect = chai.expect;

chai.use(bnChai(BN));
chai.use(require('chai-as-promised'))
chai.should();

const Cybercon = artifacts.require("Cybercon");

contract("Cybercon", (accounts) => {
    
    let cybercon;
    let auctionStartBlock;
    let auctionStartTime;
    let ticketsFunds = new BN('0');
    let ticketsBids = [];
    let buyTicketTxs = [];
    
    const ApplicationStatus = {
        Applied: 0,
        Accepted: 1,
        Declined: 2
    }
    
    function calculatedPrice(currentBlock) {
        let passedBlocks = (new BN(currentBlock.toString())).sub(new BN(auctionStartBlock.toString()));
        let currentDiscount = passedBlocks.mul(BID_BLOCK_DECREASE);
        if ((INITIAL_PRICE.sub(MINIMAL_PRICE)).cmp(currentDiscount)) {
            return INITIAL_PRICE.sub(currentDiscount);
        } else { return MINIMAL_PRICE; }
    }
    
    function calculatedOrganizersShares(time) {
        let timeDiff = (new BN(time.toString())).sub(auctionStartTime);
        let totalTime = (new BN(CHECKIN_START.toString())).sub(new BN(auctionStartTime.toString()));
        let timeDiff100 = new BN(timeDiff.mul(new BN('100'))); // refactor this line
        let mul = timeDiff100.div(totalTime); // with thiss
        let divShares = (new BN(SPEAKERS_START_SHARES.toString())).sub(new BN(SPEAKERS_END_SHARES.toString()));
        let divSharesMul = divShares.mul(mul);
        let calcCurrentSharesAdd = divSharesMul.div(new BN('100'));
        let organizerShares = calcCurrentSharesAdd.add(new BN(SPEAKERS_END_SHARES.toString()));
        return organizerShares;
    }
    
    const CYBERCON_ORGANIZER = accounts[0];
    
    const CYBERCON_NAME = "cyberc1n";
    const CYBERCON_SYMBOL = "CYBERC1N";
    const CYBERCON_DESCRIPTION = "CYBACA RELEASE";
    const CYBERCON_PLACE = "Phangan";
    
    const TICKETS_AMOUNT = 146;
    const SPEAKERS_SLOTS = 24;
    
    const SPEAKERS_START_SHARES = 80;
    const SPEAKERS_END_SHARES = 20;
    
    const INITIAL_PRICE = web3.utils.toWei(new BN(3000), 'finney');
    const MINIMAL_PRICE = web3.utils.toWei(new BN(500), 'finney');
    const BID_BLOCK_DECREASE = web3.utils.toWei(new BN(30), 'szabo');
    const MINIMAL_SPEAKER_DEPOSIT = web3.utils.toWei(new BN(1000), 'finney');

    const TALKS_APPLICATION_END = Math.round(Date.now() / 1000) + 2*24*60*60;
	const CHECKIN_START = TALKS_APPLICATION_END + 1*24*60*60;
	const CHECKIN_END = CHECKIN_START + 12*60*60;
	const DISTRIBUTION_START = CHECKIN_END + 1*60*60;

    const TIMINGS_SET = [TALKS_APPLICATION_END, CHECKIN_START, CHECKIN_END, DISTRIBUTION_START];
	const ECONOMY_SET = [INITIAL_PRICE, MINIMAL_PRICE, BID_BLOCK_DECREASE, MINIMAL_SPEAKER_DEPOSIT];
	const EVENT_SET = [TICKETS_AMOUNT, SPEAKERS_SLOTS]

    before(async () => {
        
        cybercon = await Cybercon.new(
            TIMINGS_SET,
            ECONOMY_SET,
            EVENT_SET,
            CYBERCON_NAME,
            CYBERCON_SYMBOL,
            CYBERCON_DESCRIPTION,
            CYBERCON_PLACE,
            { from: CYBERCON_ORGANIZER }
        );
        auctionStartBlock = await cybercon.getAuctionStartBlock();
        auctionStartTime = await cybercon.getAuctionStartTime();
        console.log("cybercon0 address: ", cybercon.address);
        console.log("deployed time: ", auctionStartTime.toString());
    })
    
    describe("when deployed", () => {
        it("name should equal", async() => {
            (await cybercon.name()).should.equal(CYBERCON_NAME);
        });
        
        it("token symbol should equal", async() => {
            (await cybercon.symbol()).should.equal(CYBERCON_SYMBOL);
        });
        
        it("checkin start time should equal", async() => {
            (await cybercon.getEventStartTime()).toNumber().should.equal(CHECKIN_START);
        });
        
        it("checkin end time should equal", async() => {
            (await cybercon.getEventEndTime()).toNumber().should.equal(CHECKIN_END);
        });
        
        it("distribution start time time should equal", async() => {
            (await cybercon.getDistributionTime()).toNumber().should.equal(DISTRIBUTION_START);
        });
        
        it("initial organizers and speakers shares should be equal", async() => {
            (await cybercon.getOrganizersShares()).toNumber().should.equal(SPEAKERS_END_SHARES);
            (await cybercon.getSpeakersShares()).toNumber().should.equal(SPEAKERS_START_SHARES);
            (SPEAKERS_END_SHARES + SPEAKERS_START_SHARES).should.be.equal(100);
        });
        
        it("tickets amount should equal", async() => {
            (await cybercon.getTicketsAmount()).toNumber().should.equal(TICKETS_AMOUNT);
        });
        
        it("speakers slots should equeal", async() => {
            (await cybercon.getSpeakersSlots()).toNumber().should.equal(SPEAKERS_SLOTS);
        });
        
        it("place symbol should equeal", async() => {
            (await cybercon.getPlace()).should.equal(CYBERCON_PLACE);
        });
        
        it("initial price should be equal", async() => {
            expect(await cybercon.getCurrentPrice()).to.eq.BN(calculatedPrice(await time.latestBlock()));
        });
    })
    
    describe("when auction started", () => {
        it("should start dutch auction, distribute first half of tickets", async() => {
            for (var i = 0; i < TICKETS_AMOUNT/2; i++){
                let bid = calculatedPrice((await time.latestBlock()).add(new BN('1')));
                ticketsBids.push(bid);
                let tx = await cybercon.buyTicket({ from: accounts[i], value: bid }).should.be.fulfilled;                
                buyTicketTxs.push(tx);
                ticketsFunds.iadd(bid);
    
                let bidFromContract = await cybercon.getTicket(i);
                expect(bidFromContract[0]).to.eq.BN(bid);
                bidFromContract[1].should.be.equal(accounts[i]);
                bidFromContract[2].should.be.equal(false);
                await cybercon.buyTicket({ from: accounts[i], value: bid }).should.be.rejected;
    
                await time.increase(50);
            }
    
            expect(await web3.eth.getBalance(cybercon.address)).to.eq.BN(ticketsFunds);
            expect(await cybercon.getTicketsFunds()).to.eq.BN(ticketsFunds);
        });
    
        it("should apply speakers", async() => {
            let speakersDeposits = new BN('0');
            for (var i = 200; i < 232; i++){
                let talk = {
                    sn: getRandomString(32),
                    ds: getRandomString(128),
                    dt: getRandomString(256),
                    du: getRandomInt(900, 3600),
                    va: (new BN(getRandomInt(1000, 5000).toString())).mul(new BN('1000000000000000')),
                    pr: getRandomString(132)
                }
                await cybercon.applyForTalk(talk.sn, talk.ds, talk.dt, talk.du, talk.pr,
                    {
                        from: accounts[i],
                        value: talk.va
                    }
                ).should.be.fulfilled;
                speakersDeposits.iadd(talk.va);
        
                let talkFromContract = await cybercon.getTalkById(i-200);
                talkFromContract[0].should.be.equal(talk.sn);
                talkFromContract[1].should.be.equal(talk.ds);
                talkFromContract[2].should.be.equal(talk.dt);
                talkFromContract[3].toNumber().should.be.equal(talk.du);
                expect(talkFromContract[4]).to.eq.BN(talk.va);
                talkFromContract[5].should.be.equal(accounts[i]);
                talkFromContract[8].toNumber().should.be.equal(ApplicationStatus.Applied);
                talkFromContract[9].should.be.equal(talk.pr);
        
                await time.increase(60);
            }
        
            expect(await web3.eth.getBalance(cybercon.address)).to.eq.BN(ticketsFunds.add(speakersDeposits));
            (await cybercon.totalSupply()).toNumber().should.be.equal(TICKETS_AMOUNT/2);
        });
        
        it("should allow speakers to udpate their talks", async() => {
            for (var i = 200; i < 232; i++){
                let talk = {
                    ds: getRandomString(128),
                    dt: getRandomString(256),
                    pr: getRandomString(132)
                }
                await cybercon.updateTalkDescription((i-200), talk.ds, talk.dt, talk.pr,
                    {
                        from: accounts[i]
                    }
                ).should.be.fulfilled;
        
                let talkFromContract = await cybercon.getTalkById(i-200);
                talkFromContract[1].should.be.equal(talk.ds);
                talkFromContract[2].should.be.equal(talk.dt);
                talkFromContract[9].should.be.equal(talk.pr);
            }
        })
        
        it("should allow organizer accept talks", async() => {
            for (var i = 200; i < 200 + SPEAKERS_SLOTS; i++){
                await cybercon.acceptTalk((i-200),
                {
                    from: CYBERCON_ORGANIZER
                }).should.be.fulfilled;
                let talkFromContract = await cybercon.getTalkById(i-200);
                talkFromContract[8].toNumber().should.be.equal(ApplicationStatus.Accepted);
            }
            (await cybercon.getAvailableSpeaksersSlots()).toNumber().should.be.equal(0);
        })
        
        it("should allow organizer to decline talks", async() => {
            for (var i = 200 + SPEAKERS_SLOTS; i < 230; i++){
                let declinedSpeakerBalanceBefore = new BN(await web3.eth.getBalance(accounts[i]));
                await cybercon.declineTalk((i-200),
                {
                    from: CYBERCON_ORGANIZER
                }).should.be.fulfilled;
                let declinedSpeakerBalanceAfter = new BN(await web3.eth.getBalance(accounts[i]));
                let talkFromContract = await cybercon.getTalkById(i-200);
                talkFromContract[8].toNumber().should.be.equal(ApplicationStatus.Declined);
                expect(declinedSpeakerBalanceAfter.sub(declinedSpeakerBalanceBefore)).to.eq.BN(talkFromContract[4]);
            }
        })
        
        it("should allow self decline for speaker", async() => {
            await time.increaseTo(TALKS_APPLICATION_END);
            for (var i = 230; i < 232; i++){
                let declinedSpeakerBalanceBefore = new BN(await web3.eth.getBalance(accounts[i]));
                await cybercon.selfDeclineTalk((i-200),
                {
                    from: accounts[i]
                }).should.be.fulfilled;
                let declinedSpeakerBalanceAfter = new BN(await web3.eth.getBalance(accounts[i]));
                let talkFromContract = await cybercon.getTalkById(i-200);
                talkFromContract[8].toNumber().should.be.equal(ApplicationStatus.Declined);
                expect(declinedSpeakerBalanceAfter.sub(declinedSpeakerBalanceBefore)).to.gt.BN(new BN('0'));
            }
        })
        
        it("shoud continuon the dutch auction, distribute second half of tickets", async() => {
            for (var i = TICKETS_AMOUNT/2; i < TICKETS_AMOUNT; i++){                
                let bid = await calculatedPrice((await time.latestBlock()).add(new BN('1')));
                ticketsBids.push(bid);
                let tx = await cybercon.buyTicket({ from: accounts[i], value: bid }).should.be.fulfilled;                
                buyTicketTxs.push(tx);
                ticketsFunds.iadd(bid);
        
                let bidFromContract = await cybercon.getTicket(i);
                expect(bidFromContract[0]).to.eq.BN(bid);
                bidFromContract[1].should.be.equal(accounts[i]);
                bidFromContract[2].should.be.equal(false);
                await cybercon.buyTicket({ from: accounts[i], value: bid }).should.be.rejected;
        
                await time.increase(10);
            }
        
            expect(await cybercon.getTicketsFunds()).to.eq.BN(ticketsFunds);
            expect(ticketsBids.slice(-1)[0]).to.eq.BN(await cybercon.getEndPrice());
            (await cybercon.getTicketsAmount()).toNumber().should.be.equal(0);
            (await cybercon.totalSupply()).toNumber().should.be.equal(TICKETS_AMOUNT);
        });
    })
    
    describe("when conference starts", () => {
        it("shoud checkin speaksers, send tokens for them", async() => {
            await time.increaseTo(CHECKIN_START);
            for (var i = 200; i < 200 + SPEAKERS_SLOTS; i++){
                await time.increase(100);
                await cybercon.checkinSpeaker(i-200, { from: CYBERCON_ORGANIZER }).should.be.fulfilled;
                let talkFromContract = await cybercon.getTalkById(i-200);
                talkFromContract[7].should.be.equal(true);
            }
            (await cybercon.totalSupply()).toNumber().should.be.equal(TICKETS_AMOUNT+SPEAKERS_SLOTS);
        })
    
        it("should allow organizer checkin members", async() => {
            for (var i = 0; i < TICKETS_AMOUNT; i++){
                await cybercon.checkinMember(i, { from: accounts[i] });
                let bidFromContract = await cybercon.getTicket(i);
                bidFromContract[2].should.be.equal(true);
            }
        })
    })
    
    describe("when distribution starts", () => {
    
        it("should correctly distribute overbids", async() => {
            await time.increaseTo(DISTRIBUTION_START)
            let membersBalancesBefore = [];
            let endPrice = new BN(await cybercon.getEndPrice());
            for (var i = 0; i < TICKETS_AMOUNT; i++){
                membersBalancesBefore.push(new BN(await web3.eth.getBalance(accounts[i])));
            }
            await cybercon.distributeOverbids(0, TICKETS_AMOUNT/2-1, { from: CYBERCON_ORGANIZER }).should.be.fulfilled;
            await cybercon.distributeOverbids(TICKETS_AMOUNT/2, TICKETS_AMOUNT-1, { from: CYBERCON_ORGANIZER }).should.be.fulfilled;
            // for (var i = 0; i < TICKETS_AMOUNT; i++){
                // let balanceAfter = new BN(await web3.eth.getBalance(accounts[i]));
                // let diff = new BN(balanceAfter.sub(membersBalancesBefore[i]));
                // let overbid = new BN(ticketsBids[i].sub(endPrice));
                // expect(diff).to.eq.BN(overbid);
            // }
            expect(await cybercon.getAmountReturnedOverbids()).to.eq.BN(new BN(TICKETS_AMOUNT.toString()));
        })
    
        it("should correctly distribute rewards", async() => {
            let speakersBalances = [];
            for (var i = 200; i < 200+SPEAKERS_SLOTS; i++){
                speakersBalances.push(new BN(await web3.eth.getBalance(accounts[i])));
            }
            let calculatedShares = calculatedOrganizersShares(await cybercon.getAuctionEndTime());
            let calculatedSpeakersShares = (new BN('100')).sub(calculatedShares);
            console.log("_______________");
            console.log("Calculated Speakers Shares: ", calculatedSpeakersShares.toString(10));
            console.log("Actual Speakers shares: ", (await cybercon.getSpeakersShares()).toString());
            console.log("_______________");
            expect(await cybercon.getSpeakersShares()).to.eq.BN(calculatedSpeakersShares);
    
            let endPrice = new BN(await cybercon.getEndPrice());
            console.log("End Price: ", web3.utils.fromWei(await cybercon.getEndPrice(), 'ether').toString());
            console.log("_______________");
            let valueFromTicketsForReward = endPrice.mul(new BN(TICKETS_AMOUNT));
            console.log("Tickets Funds: ", web3.utils.fromWei(valueFromTicketsForReward, 'ether').toString());
            console.log("Speakers part of Funds: ", web3.utils.fromWei(valueFromTicketsForReward.mul(calculatedSpeakersShares).div(new BN('100')), 'ether').toString());
            console.log("Organers part of Funds: ", web3.utils.fromWei(valueFromTicketsForReward.mul(calculatedShares).div(new BN('100')), 'ether').toString());
            console.log("_______________");
            let organizerBalance = new BN(await web3.eth.getBalance(CYBERCON_ORGANIZER));
            let tx = await cybercon.distributeRewards({ from: CYBERCON_ORGANIZER }).should.be.fulfilled;
            console.log("Gas used by organizer to call distributeRewards: ", ((new BN(tx.receipt.gasUsed.toString())).mul(new BN('20000000000'))).toString());
            let valuePerSpeaker = (valueFromTicketsForReward.mul(calculatedSpeakersShares).div(new BN('100'))).div(new BN(SPEAKERS_SLOTS.toString()));
            for (var i = 200; i < 200+SPEAKERS_SLOTS; i++){
                let talkFromContract = await cybercon.getTalkById(i-200);
                let speakerBalanceAfter = new BN(await web3.eth.getBalance(accounts[i]));
                console.log("Speaker's talk ID: ", (i-200));
                console.log("Value for speaker's from tickets: ", web3.utils.fromWei(valuePerSpeaker, 'ether'));
                console.log("Deposit of speaker's: ", web3.utils.fromWei(talkFromContract[4], 'ether'));
                console.log("Speaker's balance before: ", web3.utils.fromWei(speakersBalances[i-200], 'ether'));
                console.log("Speaker's balance after: ", web3.utils.fromWei(speakerBalanceAfter, 'ether'));
                console.log("Speaker's balance diff: ", web3.utils.fromWei(speakerBalanceAfter.sub(speakersBalances[i-200]), 'ether'));
                console.log("_______________");
                let balanceDiff = speakerBalanceAfter.sub(speakersBalances[i-200]);
                let payment = valuePerSpeaker.add(new BN(talkFromContract[4]));
                expect(balanceDiff).to.eq.BN(payment);
            }
            let valueForOrganizer = (valueFromTicketsForReward.mul(calculatedShares).div(new BN('100')));
            let organizerBalanceAfter = new BN(await web3.eth.getBalance(CYBERCON_ORGANIZER));
            console.log("Value for organizer: ", web3.utils.fromWei(valueForOrganizer, 'ether'));
            console.log("Organizer's balance before: ", web3.utils.fromWei(organizerBalance, 'ether'));
            console.log("Organizer's balance after: ", web3.utils.fromWei(organizerBalanceAfter, 'ether'));
            console.log("Organizer's balance diff: ", web3.utils.fromWei((organizerBalanceAfter.sub(organizerBalance)), 'ether'));
            // expect(organizerBalanceAfter.sub(organizerBalance)).to.eq.BN(valueForOrganizer.sub((new BN(tx.receipt.gasUsed.toString())).mul(new BN('20000000000'))));
        })
    })
})