pragma solidity 0.4.25;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC721/ERC721Full.sol";
import "openzeppelin-solidity/contracts/utils/ReentrancyGuard.sol";


contract Cybercon is Ownable, ReentrancyGuard, ERC721Full {
    
    using SafeMath for uint256;
    
    struct Talk {
        string  speakerName;
        string  descSpeaker;
        string  deskTalk;
        uint256 duration;
        uint256 bid;
        address speakerAddress;
        uint256 appliedAt;
        bool    checkedIn;
    }
    
    struct Bid {
        uint256 value;
        address bidderAddress;
    }
    
    uint256 private auctionStart;
    uint256 private auctionEnd = 1544767200;
    uint256 private checkinStart = 1544767200;
    uint256 private checkinEnd = 1544792400;
    uint256 private distributionStart = 1544796000;
    // ------------
    uint256 private initialPrice = 1500 finney;
    uint256 private minimalPrice = 300 finney;
    uint256 private endPrice = 300 finney;
    uint256 private timeframe    = 3600;
    uint256 private timeframeDowngrade = 3 finney;
    // ------------
    uint8 private   ticketsAmount = 200;
    uint8 private   speakersSlots = 8;
    uint256 private speakearsStartShares = 80;
    uint256 private speakersEndShares = 20;
    // ------------
    uint256 private ticketsFunds = 0;
    uint256 private speakersDeposits = 0;
    uint256 private speakersCheckinDeposits = 0;
    // ------------
    string private  eventSpace = "Korpus 8";
    
    mapping(address => bool) private membersBidded;
    bool private bidsDistributed = false;
    
    Bid[]  private membersBids;
    Talk[] private speakersTalks;
    
    event TicketBid(
        uint256 _id,
        address _member,
        uint256 _value
    );
    
    event TalkApplication(
        string  _name,
        address _member,
        uint256 _value
    );
    
    event SpeakerCheckin(
        uint8   _talkId,
        address _member
    );
    
    constructor() ERC721Full("Cybercon0", "CYBERCON0")
        public
    {
        auctionStart = block.timestamp;
    }
    
    function() external {}
    
    modifier beforeEventStart() {
        require(block.timestamp < checkinStart);
        _;
    }

    function buyTicket()
        external
        beforeEventStart
        nonReentrant
        payable
    {
        require(msg.value >= getCurrentPrice());
        require(membersBidded[msg.sender] == false);
        require(ticketsAmount > 0);
        
        uint256 bidId = totalSupply();
        membersBids.push(Bid(msg.value, msg.sender));
        super._mint(msg.sender, bidId);
        membersBidded[msg.sender] = true;
        ticketsFunds = ticketsFunds.add(msg.value);
        ticketsAmount--;
        
        if (ticketsAmount == 0) auctionEnd = block.timestamp;
        
        emit TicketBid(bidId, msg.sender, msg.value);
    }
    
    function applyForTalk(
        string _speakerName,
        string _descSpeaker,
        string _deskTalk,
        uint256 _duration
    )
        external
        beforeEventStart
        nonReentrant
        payable
    {
        require(_duration >= 900 && _duration <= 3600);
        require(msg.value > 0);
        require(uint8(speakersTalks.length) < speakersSlots);
        
        Talk memory t = (Talk(
        {
            speakerName: _speakerName,
            descSpeaker: _descSpeaker,
            deskTalk:    _deskTalk,
            duration:    _duration,
            bid:         msg.value,
            speakerAddress: msg.sender,
            appliedAt:   block.timestamp,
            checkedIn:   false
        }));
        speakersDeposits = speakersDeposits.add(msg.value);
        speakersTalks.push(t);
        
        emit TalkApplication(_speakerName, msg.sender, msg.value);
    }
    
    function checkinSpeaker(uint8 _talkId)
        external
        onlyOwner
        nonReentrant
    {
        require(block.timestamp >= checkinStart && block.timestamp < checkinEnd);
        require(speakersTalks[_talkId].checkedIn == false);
        
        uint256 bidId = totalSupply();
        super._mint(msg.sender, bidId);
        speakersTalks[_talkId].checkedIn = true;
        speakersCheckinDeposits = speakersCheckinDeposits.add(speakersTalks[_talkId].bid);
        
        emit SpeakerCheckin(_talkId, msg.sender);
    }
    
    function distributeBids()
        external
        nonReentrant
    {   
        require(block.timestamp > distributionStart);
        uint256 checkedInSpeakers = 0;
        for (uint8 y = 0; y < speakersTalks.length; y++){
            if (speakersTalks[y].checkedIn) checkedInSpeakers++;
        }
        for (uint256 i = 0; i < totalSupply().sub(checkedInSpeakers); i++) {
            address bidderAddress = membersBids[i].bidderAddress;
            uint256 bidderValue = membersBids[i].value;
            address(bidderAddress).transfer(bidderValue.sub(endPrice));
        }
        bidsDistributed = true;
        address(msg.sender).transfer(1000000000000000000); // transfer 1 ETH to caller
    }
    
    function distributeRewards()
        external
        nonReentrant
    {
        require(bidsDistributed == true);
        require(block.timestamp > distributionStart);
        uint256 checkedInSpeakers = 0;
        if (speakersTalks.length > 0) {
            for (uint8 i = 0; i < speakersTalks.length; i++){
                if (speakersTalks[i].checkedIn) checkedInSpeakers++;
            }
            uint256 valueForTicketsForReward = endPrice.mul(membersBids.length);
            uint256 valueFromTicketsForSpeakers = 0;
            if (auctionEnd != checkinStart) {
                uint256 mul = auctionEnd.sub(auctionStart).mul(100).div(checkinStart.sub(auctionStart));
                uint256 shares = speakearsStartShares.sub(speakersEndShares).mul(mul).div(100);
                uint256 speakersShares = speakersEndShares.add(shares);
                valueFromTicketsForSpeakers = valueForTicketsForReward.mul(speakersShares).div(100);
            } else {
                valueFromTicketsForSpeakers = valueForTicketsForReward.mul(speakersEndShares).div(100);
            }
            
            uint256 valuePerSpeakerFromTickets = valueFromTicketsForSpeakers.div(checkedInSpeakers);
            for (uint8 y = 0; y < speakersTalks.length; y++) {
                if (speakersTalks[y].checkedIn) {
                    address(speakersTalks[y].speakerAddress).transfer(valuePerSpeakerFromTickets.add(speakersTalks[y].bid));
                }
            }
        }
        address(msg.sender).transfer(1000000000000000000); // transfer 1 ETH to caller
        address(owner()).transfer(address(this).balance);
    }
    
    function getCurrentPrice()
        public
        view
        returns(uint256)
    {
        uint256 secondsPassed = block.timestamp - auctionStart;
        uint256 currentDiscount = (secondsPassed.div(timeframe)).mul(timeframeDowngrade);
        
        if (currentDiscount < (initialPrice - minimalPrice)) {
            return initialPrice.sub(currentDiscount);
        } else { 
            return minimalPrice; 
        }
    }
    
    function getTalkById(uint8 _id)
        external
        view
        returns(
            string,
            string,
            string,
            uint256,
            uint256,
            address,
            uint256,
            bool
        )
    {
        require(_id < uint8(speakersTalks.length));
        Talk memory m = speakersTalks[_id];
        return(
            m.speakerName,
            m.descSpeaker,
            m.deskTalk,
            m.duration,
            m.bid,
            m.speakerAddress,
            m.appliedAt,
            m.checkedIn
        );
    }
    
    function getBidForTicket(uint256 _id)
        external
        view
        returns(uint256, address)
    {
        return(
            membersBids[_id].value,
            membersBids[_id].bidderAddress
        );
    }
    
    function getAuctionStartTime()
        external
        view
        returns(uint256)
    {
        return auctionStart;
    }
    
    function getAuctionEndTime()
        external
        view
        returns(uint256)
    {
        return auctionEnd;
    }
    
    function getEventStartTime()
        external
        view
        returns(uint256)
    {
        return checkinStart;
    }
    
    function getEventEndTime()
        external
        view
        returns(uint256)
    {
        return checkinEnd;
    }
    
    function getDistributionTime()
        external
        view
        returns(uint256)
    {
        return distributionStart;
    }
    
    function getMinimalPrice()
        external
        view
        returns(uint256)
    {
        return minimalPrice;
    }
    
    function getTicketsAmount()
        external
        view
        returns(uint8)
    {
        return ticketsAmount;
    }
    
    function getSpeakersSlots()
        external
        view
        returns(uint8)
    {
        return speakersSlots;
    }
    
    function getAvailableSpeaksersSlots()
        external
        view
        returns(uint8)
    { 
        return speakersSlots - uint8(speakersTalks.length); 
    }
    
    function getOrganizersShares()
        external
        view
        returns(uint256)
    {
        return uint256(100).sub(getSpeakersShares());
    }
    
    function getSpeakersShares()
        public
        view
        returns(uint256)
    {
        uint256 time = auctionEnd;
        if ( ticketsAmount > 0 ) time = block.timestamp;
        uint256 mul = time.sub(auctionStart).mul(100).div(checkinStart.sub(auctionStart));
        uint256 shares = speakearsStartShares.sub(speakersEndShares).mul(mul).div(100);
        return speakersEndShares.add(shares);
    }
    
    function getTicketsFunds()
        external
        view
        returns(uint256)
    {
        return ticketsFunds;
    }
    
    function getSpeakersDeposits()
        external
        view
        returns(uint256)
    {
        return speakersDeposits;
    }
    
    function getPlace()
        external
        view
        returns(string)
    { 
        return eventSpace;
    }
}