pragma solidity 0.4.25;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC721/ERC721Full.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/utils/Address.sol";


contract Cybercon is Ownable, ERC721Full {
    
    using SafeMath for uint256;
    using Address for address;
    
    enum ApplicationStatus {Applied, Accepted, Declined}
    
    struct Talk {
        string  speakerName;
        string  descSpeaker;
        string  deskTalk;
        uint256 duration;
        uint256 deposit;
        address speakerAddress;
        uint256 appliedAt;
        bool    checkedIn;
        ApplicationStatus status;
        string  proof;
    }
    
    struct Ticket {
        uint256 value;
        address bidderAddress;
        bool    checkedIn;
        bool    overbidReturned;
    }
    
    struct CommunityBuilderMessage {
        string  message;
        string  link1;
        string  link2;
        uint256 donation;
    }
    
    uint256 private auctionStart;
    uint256 constant private TALKS_APPLICATION_END = 1544562000;
    uint256 constant private CHECKIN_START = 1544767200;
    uint256 constant private CHECKIN_END = 1544788800;
    uint256 constant private DISTRIBUTION_START = 1544792400;
    uint256 private auctionEnd = CHECKIN_START;
    // ------------
    uint256 constant private INITIAL_PRICE = 3000 finney;
    uint256 constant private MINIMAL_PRICE = 500 finney;
    uint256 constant private TIMEFRAME = 13;
    uint256 constant private BID_TIMEFRAME_DECREASE = 30 szabo;
    uint256 private endPrice = MINIMAL_PRICE;
    // ------------
    uint256 private ticketsAmount = 146;
    uint256 constant private SPEAKERS_SLOTS = 24;
    uint256 private acceptedSpeakersSlots = 0;
    uint256 constant private SPEAKERS_START_SHARES = 80;
    uint256 constant private SPEAKERS_END_SHARES = 20;
    // ------------
    uint256 private ticketsFunds = 0;
    uint256 constant private MINIMAL_SPEAKER_DEPOSIT = 1000 finney;
    // ------------
    string constant private CYBERCON_PLACE = "Korpus 8, Minsk, Belarus";
    
    mapping(address => bool) private membersBidded;
    uint256 private amountReturnedBids = 0;
    bool private overbidsDistributed = false;
    
    Talk[] private speakersTalks;
    Ticket[] private membersTickets;
    CommunityBuilderMessage[] private communityBuildersBoard;
    
    string private talksGrid = "";
    string private workshopsGrid = "";
    
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
    
    constructor() ERC721Full("cyberc0n", "CYBERC0N")
        public
    {
        auctionStart = block.timestamp;
    }
    
    function() external {}
    
    modifier beforeApplicationStop() {
        require(block.timestamp < TALKS_APPLICATION_END);
        _;
    }
    
    modifier beforeEventStart() {
        require(block.timestamp < CHECKIN_START);
        _;
    }
    
    modifier duringEvent() {
        require(block.timestamp >= CHECKIN_START && block.timestamp <= CHECKIN_END);
        _;
    }
    
    modifier afterDistributionStart() {
        require(block.timestamp > DISTRIBUTION_START);
        _;
    }

    function buyTicket()
        external
        beforeEventStart
        payable
    {
        require(msg.value >= getCurrentPrice());
        require(membersBidded[msg.sender] == false);
        require(ticketsAmount > 0);
        
        uint256 bidId = totalSupply();
        membersTickets.push(Ticket(msg.value, msg.sender, false, false));
        super._mint(msg.sender, bidId);
        membersBidded[msg.sender] = true;
        ticketsFunds = ticketsFunds.add(msg.value);
        ticketsAmount = ticketsAmount.sub(1);
        
        if (ticketsAmount == 0) {
            auctionEnd = block.timestamp;
            endPrice = msg.value;
        }
        
        emit TicketBid(bidId, msg.sender, msg.value);
    }
    
    function applyForTalk(
        string  _speakerName,
        string  _descSpeaker,
        string  _deskTalk,
        uint256 _duration,
        string  _proof
    )
        external
        beforeApplicationStop
        payable
    {
        require(_duration >= 900 && _duration <= 3600);
        require(msg.value >= MINIMAL_SPEAKER_DEPOSIT);
        require(speakersTalks.length < 36);
        
        Talk memory t = (Talk(
        {
            speakerName: _speakerName,
            descSpeaker: _descSpeaker,
            deskTalk:    _deskTalk,
            duration:    _duration,
            deposit:     msg.value,
            speakerAddress: msg.sender,
            appliedAt:   block.timestamp,
            checkedIn:   false,
            status:      ApplicationStatus.Applied,
            proof:       _proof
        }));
        speakersTalks.push(t);
        
        emit TalkApplication(_speakerName, msg.sender, msg.value);
    }

    function sendCommunityBuilderMessage(
        uint256 _talkId,
        string _message,
        string _link1,
        string _link2
    )
        external
        beforeEventStart
        payable
    {
        require(speakersTalks[_talkId].speakerAddress == msg.sender);
        require(speakersTalks[_talkId].status == ApplicationStatus.Accepted);
        require(msg.value > 0);
        
        CommunityBuilderMessage memory m = (CommunityBuilderMessage(
        {
            message: _message,
            link1:   _link1,
            link2:   _link2,
            donation: msg.value
        }));
        communityBuildersBoard.push(m);
    }
    
    function updateTalkDescription(
        uint256 _talkId,
        string  _descSpeaker,
        string  _deskTalk,
        string  _proof
    )
        external
        beforeApplicationStop
    {
        require(msg.sender == speakersTalks[_talkId].speakerAddress);
        speakersTalks[_talkId].descSpeaker = _descSpeaker;
        speakersTalks[_talkId].deskTalk = _deskTalk;
        speakersTalks[_talkId].proof = _proof;
    }
    
    function acceptTalk(uint256 _talkId)
        external
        onlyOwner
        beforeEventStart
    {
        require(acceptedSpeakersSlots < SPEAKERS_SLOTS); 
        require(speakersTalks[_talkId].status == ApplicationStatus.Applied);
        acceptedSpeakersSlots = acceptedSpeakersSlots.add(1);
        speakersTalks[_talkId].status = ApplicationStatus.Accepted;
    }
    
    function declineTalk(uint256 _talkId)
        external
        onlyOwner
        beforeEventStart
    {
        speakersTalks[_talkId].status = ApplicationStatus.Declined;
        address speakerAddress = speakersTalks[_talkId].speakerAddress;
        if (speakerAddress.isContract() == false) {
            address(speakerAddress).transfer(speakersTalks[_talkId].deposit);
        }
    }
    
    function selfDeclineTalk(uint256 _talkId)
        external
    {
        require(block.timestamp >= TALKS_APPLICATION_END && block.timestamp < CHECKIN_START);
        address speakerAddress = speakersTalks[_talkId].speakerAddress;
        require(msg.sender == speakerAddress);
        require(speakersTalks[_talkId].status == ApplicationStatus.Applied);
        speakersTalks[_talkId].status = ApplicationStatus.Declined;
        if (speakerAddress.isContract() == false) {
            address(speakerAddress).transfer(speakersTalks[_talkId].deposit);
        }
    }
    
    function checkinMember(uint256 _id)
        external
        duringEvent
    {
        require(membersTickets[_id].bidderAddress == msg.sender);
        membersTickets[_id].checkedIn = true;
    }
    
    function checkinSpeaker(uint256 _talkId)
        external
        onlyOwner
        duringEvent
    {
        require(speakersTalks[_talkId].checkedIn == false);
        require(speakersTalks[_talkId].status == ApplicationStatus.Accepted);
        
        uint256 bidId = totalSupply();
        super._mint(msg.sender, bidId);
        speakersTalks[_talkId].checkedIn = true;
    }
    
    function distributeOverbids(uint256 _fromBid, uint256 _toBid)
        external
        onlyOwner
        afterDistributionStart
    {   
        require(_fromBid <= _toBid);
        uint256 checkedInSpeakers = 0;
        for (uint256 y = 0; y < speakersTalks.length; y++){
            if (speakersTalks[y].checkedIn) checkedInSpeakers++;
        }
        uint256 ticketsForMembersSupply = totalSupply().sub(checkedInSpeakers);
        require(_fromBid < ticketsForMembersSupply && _toBid < ticketsForMembersSupply);
        for (uint256 i = _fromBid; i <= _toBid; i++) {
            require(membersTickets[i].overbidReturned == false);
            address bidderAddress = membersTickets[i].bidderAddress;
            uint256 overbid = (membersTickets[i].value).sub(endPrice);
            if(bidderAddress.isContract() == false) {
                address(bidderAddress).transfer(overbid);
            }
            membersTickets[i].overbidReturned = true;
            amountReturnedBids++;
        }
        if (amountReturnedBids == ticketsForMembersSupply) {
            overbidsDistributed = true;
        }
    }
    
    function distributeRewards()
        external
        onlyOwner
        afterDistributionStart
    {
        require(overbidsDistributed == true);
        if (acceptedSpeakersSlots > 0) {
            uint256 checkedInSpeakers = 0;
            for (uint256 i = 0; i < speakersTalks.length; i++){
                if (speakersTalks[i].checkedIn) checkedInSpeakers++;
            }
            uint256 valueForTicketsForReward = endPrice.mul(membersTickets.length);
            uint256 valueFromTicketsForSpeakers = valueForTicketsForReward.mul(getSpeakersShares()).div(100);
            
            uint256 valuePerSpeakerFromTickets = valueFromTicketsForSpeakers.div(checkedInSpeakers);
            for (uint256 y = 0; y < speakersTalks.length; y++) {
                address speakerAddress = speakersTalks[y].speakerAddress;
                if (speakersTalks[y].checkedIn == true && speakerAddress.isContract() == false) {
                    speakerAddress.transfer(valuePerSpeakerFromTickets.add(speakersTalks[y].deposit));
                }
            }
        }
        address(owner()).transfer(address(this).balance);
    }
    
    function setTalksGrid(string _grid)
        external
        onlyOwner
    {
        talksGrid = _grid;
    }
    
    function setWorkshopsGrid(string _grid)
        external
        onlyOwner
    {
        workshopsGrid = _grid;
    }
    
    function getTalkById(uint256 _id)
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
            bool,
            ApplicationStatus,
            string 
        )
    {
        require(_id < uint256(speakersTalks.length));
        Talk memory m = speakersTalks[_id];
        return(
            m.speakerName,
            m.descSpeaker,
            m.deskTalk,
            m.duration,
            m.deposit,
            m.speakerAddress,
            m.appliedAt,
            m.checkedIn,
            m.status,
            m.proof
        );
    }
    
    function getTicket(uint256 _id)
        external
        view
        returns(
            uint256,
            address,
            bool,
            bool
        )
    {
        return(
            membersTickets[_id].value,
            membersTickets[_id].bidderAddress,
            membersTickets[_id].checkedIn,
            membersTickets[_id].overbidReturned
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
        pure
        returns(uint256)
    {
        return CHECKIN_START;
    }
    
    function getEventEndTime()
        external
        pure
        returns(uint256)
    {
        return CHECKIN_END;
    }
    
    function getDistributionTime()
        external
        pure
        returns(uint256)
    {
        return DISTRIBUTION_START;
    }
    
    function getCurrentPrice()
        public
        view
        returns(uint256)
    {
        uint256 secondsPassed = block.timestamp - auctionStart;
        uint256 currentDiscount = (secondsPassed.div(TIMEFRAME)).mul(BID_TIMEFRAME_DECREASE);
        
        if (currentDiscount < (INITIAL_PRICE - MINIMAL_PRICE)) {
            return INITIAL_PRICE.sub(currentDiscount);
        } else { 
            return MINIMAL_PRICE; 
        }
    }
    
    function getEndPrice()
        external
        view
        returns(uint256)
    {
        return endPrice;
    }
    
    function getMinimalPrice()
        external
        pure
        returns(uint256)
    {
        return MINIMAL_PRICE;
    }
    
    function getMinimalSpeakerDeposit()
        external
        pure
        returns(uint256)
    {
        return MINIMAL_SPEAKER_DEPOSIT;
    }
    
    function getTicketsAmount()
        external
        view
        returns(uint256)
    {
        return ticketsAmount;
    }
    
    function getSpeakersSlots()
        external
        pure
        returns(uint256)
    {
        return SPEAKERS_SLOTS;
    }
    
    function getAvailableSpeaksersSlots()
        external
        view
        returns(uint256)
    { 
        return SPEAKERS_SLOTS.sub(acceptedSpeakersSlots); 
    }
    
    function getOrganizersShares()
        public
        view
        returns(uint256)
    {
        uint256 time = auctionEnd;
        if (ticketsAmount > 0 && block.timestamp < CHECKIN_START) {
            time = block.timestamp;
        }
        uint256 mul = time.sub(auctionStart).mul(100).div(CHECKIN_START.sub(auctionStart));
        uint256 shares = SPEAKERS_START_SHARES.sub(SPEAKERS_END_SHARES).mul(mul).div(100);
        
        return SPEAKERS_END_SHARES.add(shares);
    }
    
    function getSpeakersShares()
        public
        view
        returns(uint256)
    {
        return uint256(100).sub(getOrganizersShares());
    }
    
    function getTicketsFunds()
        external
        view
        returns(uint256)
    {
        return ticketsFunds;
    }
    
    function getPlace()
        external
        pure
        returns(string)
    { 
        return CYBERCON_PLACE;
    }
    
    function getTalksGrid()
        external
        view
        returns(string)
    {
        return talksGrid;
    }
    
    function getWorkshopsGrid()
        external
        view
        returns(string)
    {
        return workshopsGrid;
    }
    
    function getCommunityBuilderMessage(uint256 _messageID)
        external
        view
        returns(
            string,
            string,
            string,
            uint256
        )
    {
        return(
            communityBuildersBoard[_messageID].message,
            communityBuildersBoard[_messageID].link1,
            communityBuildersBoard[_messageID].link2,
            communityBuildersBoard[_messageID].donation
        );
    }
    
    function getCommunityBuildersBoardSize()
        external
        view
        returns(uint256)
    {
        return communityBuildersBoard.length;
    }
    
    function getAmountReturnedOverbids()
        external
        view
        returns(uint256)
    {
        return amountReturnedBids;
    }
}