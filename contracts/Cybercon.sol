pragma solidity 0.5.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC721/ERC721Full.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/utils/Address.sol";


contract Cybercon is Ownable, ERC721Full {

    using SafeMath for uint256;
    using Address for address;
    using Address for address payable;

    enum ApplicationStatus {Applied, Accepted, Declined}

    struct Talk {
        string  speakerName;
        string  descSpeaker;
        string  deskTalk;
        uint256 duration;
        uint256 deposit;
        address payable speakerAddress;
        uint256 appliedAt;
        bool    checkedIn;
        ApplicationStatus status;
        string  proof;
    }
    struct Ticket {
        uint256 value;
        address payable bidderAddress;
        bool    checkedIn;
        bool    overbidReturned;
    }
    struct CommunityBuilderMessage {
        string  message;
        string  link1;
        string  link2;
        uint256 donation;
    }

    uint256 private auctionStartBlock;
    uint256 private auctionStartTime;
    uint256 private talksApplicationEnd;
    uint256 private checkinStart;
    uint256 private checkinEnd;
    uint256 private distributionStart;
    uint256 private auctionEnd;

    uint256 private initialPrice;
    uint256 private minimalPrice;
    uint256 private bidBlockDecrease;
    uint256 private endPrice;

    uint256 private ticketsAmount;
    uint256 private totalTickets;
    uint256 private speakersSlots;
    uint256 private minimalSpeakerDeposit;
    uint256 private ticketsFunds = 0;
    uint256 private acceptedSpeakersSlots = 0;
    uint256 constant private SPEAKERS_START_SHARES = 80;
    uint256 constant private SPEAKERS_END_SHARES = 20;

    string private eventPlace;
    string private eventDescription;

    mapping(address => bool) private membersBidded;
    mapping(address => uint256) private ticketByAddressIndex;
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

    event BuilderMessage(
        uint256 _talkId,
        string _message,
        string _link1,
        string _link2
    );

    event TalkAccepted(uint256 _talkId);
    event TalkDeclined(uint256 _talkId);
    event TalkSelfDeclined(uint256 _talkId);
    event MemberCheckin(uint256 _ticketId);
    event SpeakerCheckin(uint256 _talkId);
    event OverbidsDistributed();
    event RewardsDistributed();
    event UpdatedTalksGrid(string _grid);
    event UpdatedWorkshopsGrid(string _grid);
    event debug(uint256 _passed);


    // tickets amount
    // ticket fix price
    // organizator bond amount
    // max time investments round
    // limb time
    // speculative time?

    //function cancel



    constructor(
        uint256[] memory _timingsSet,
        uint256[] memory _economySet,
        uint256[] memory _eventSet,
        string memory _name,
        string memory _symbol,
        string memory _description,
        string memory _place
    ) ERC721Full(_name, _symbol)
        public
    {
        require(_timingsSet[0] > block.timestamp, "talks applications end should be later than auction started"); // solium-disable-line security/no-block-members, max-len
        require(_timingsSet[1] > _timingsSet[0], "checkin start should be later than applications end");
        require(_timingsSet[2] > _timingsSet[1], "checking end should later than checkin start");
        require(_timingsSet[3] > _timingsSet[2], "distribution end should be later than checkin end");

        require(_economySet[0] > _economySet[1], "start price should be highter than minimal price");
        require(_economySet[3] >= 1 ether, "minimal speaker deposit should be highter than 1 eth");

        require(_eventSet[0] <= 200, "tickets amount should be less than 200");
        require(_eventSet[1] <= 24, "speaker's slots amount should be less than 24");

        auctionStartBlock = block.number;
        auctionStartTime = block.timestamp; // solium-disable-line security/no-block-members

        talksApplicationEnd = _timingsSet[0];
        checkinStart = _timingsSet[1];
        checkinEnd = _timingsSet[2];
        distributionStart = _timingsSet[3];
        auctionEnd = checkinStart;

        initialPrice = _economySet[0];
        minimalPrice = _economySet[1];
        bidBlockDecrease = _economySet[2];
        minimalSpeakerDeposit = _economySet[3];
        endPrice = minimalPrice;

        ticketsAmount = _eventSet[0];
        speakersSlots = _eventSet[1];
        totalTickets = ticketsAmount;

        eventPlace = _place;
        eventDescription = _description;
    }

    function() external {}

    modifier beforeApplicationStop() {
        require(block.timestamp < talksApplicationEnd, "only before application finished"); // solium-disable-line security/no-block-members
        _;
    }

    modifier beforeEventStart() {
        require(block.timestamp < checkinStart, "only before event started"); // solium-disable-line security/no-block-members
        _;
    }

    modifier duringEvent() {
        require(block.timestamp >= checkinStart && block.timestamp <= checkinEnd, "only when event going"); // solium-disable-line security/no-block-members, max-len
        _;
    }

    modifier afterDistributionStart() {
        require(block.timestamp > distributionStart, "only when distribuion allowed"); // solium-disable-line security/no-block-members
        _;
    }

    function buyTicket()
        external
        beforeEventStart
        payable
    {
        require(msg.value >= getCurrentPrice(), "bid should be equal or more than current price");
        require(membersBidded[msg.sender] == false, "should buy only one ticket by address");
        require(ticketsAmount > 0, "no more tickets, sorry");

        uint256 bidId = totalSupply();
        membersTickets.push(Ticket(msg.value, msg.sender, false, false));
        super._mint(msg.sender, bidId);
        membersBidded[msg.sender] = true;
        ticketByAddressIndex[msg.sender] = bidId;
        ticketsFunds = ticketsFunds.add(msg.value);
        ticketsAmount = ticketsAmount.sub(1);

        if (ticketsAmount == 0) {
            auctionEnd = block.timestamp; // solium-disable-line security/no-block-members
            endPrice = getCurrentPrice();
        }

        emit TicketBid(bidId, msg.sender, msg.value);
    }

    function applyForTalk(
        string calldata _speakerName,
        string calldata _descSpeaker,
        string calldata _deskTalk,
        uint256 _duration,
        string calldata _proof
    )
        external
        beforeApplicationStop
        payable
    {
        require(_duration >= 900 && _duration <= 3600, "talks duration should me in given limits");
        require(msg.value >= minimalSpeakerDeposit, "amount should be equal or more than minimal deposit");
        require(speakersTalks.length < 36, "exceed amount of speakers applications");

        Talk memory t = (Talk(
        {
            speakerName: _speakerName,
            descSpeaker: _descSpeaker,
            deskTalk: _deskTalk,
            duration: _duration,
            deposit: msg.value,
            speakerAddress: msg.sender,
            appliedAt: block.timestamp, // solium-disable-line security/no-block-members, no-trailing-whitespace, whitespace
            checkedIn: false,
            status: ApplicationStatus.Applied,
            proof: _proof
        }));
        speakersTalks.push(t);

        emit TalkApplication(_speakerName, msg.sender, msg.value);
    }

    function sendCommunityBuilderMessage(
        uint256 _talkId,
        string calldata _message,
        string calldata _link1,
        string calldata _link2
    )
        external
        beforeEventStart
        payable
    {
        require(speakersTalks[_talkId].speakerAddress == msg.sender, "should allow to add builder message only for speaker //todo remove this");
        require(speakersTalks[_talkId].status == ApplicationStatus.Accepted, "should allow add builder message only for accepted speakers");
        require(msg.value > 0, "builder should provide fee");

        CommunityBuilderMessage memory m = (CommunityBuilderMessage(
        {
            message: _message,
            link1: _link1,
            link2: _link2,
            donation: msg.value
        }));
        communityBuildersBoard.push(m);

        emit BuilderMessage(_talkId, _message, _link1, _link2);
    }

    function updateTalkDescription(
        uint256 _talkId,
        string calldata _descSpeaker,
        string calldata _deskTalk,
        string calldata _proof
    )
        external
        beforeApplicationStop
    {
        require(msg.sender == speakersTalks[_talkId].speakerAddress, "should allow change only given speakers talk's data");
        speakersTalks[_talkId].descSpeaker = _descSpeaker;
        speakersTalks[_talkId].deskTalk = _deskTalk;
        speakersTalks[_talkId].proof = _proof;
    }

    function acceptTalk(uint256 _talkId)
        external
        onlyOwner
        beforeEventStart
    {
        require(acceptedSpeakersSlots < speakersSlots, "should allow accept amount of talks which less than available slots");
        require(speakersTalks[_talkId].status == ApplicationStatus.Applied, "should only accept not declined talks");
        acceptedSpeakersSlots = acceptedSpeakersSlots.add(1);
        speakersTalks[_talkId].status = ApplicationStatus.Accepted;

        emit TalkAccepted(_talkId);
    }

    function declineTalk(uint256 _talkId)
        external
        onlyOwner
        beforeEventStart
    {
        speakersTalks[_talkId].status = ApplicationStatus.Declined;
        address payable speakerAddress = speakersTalks[_talkId].speakerAddress;
        if (speakerAddress.isContract() == false) {
            address(speakerAddress).transfer(speakersTalks[_talkId].deposit);
        }

        emit TalkDeclined(_talkId);
    }

    function selfDeclineTalk(uint256 _talkId)
        external
    {
        require(block.timestamp >= talksApplicationEnd && block.timestamp < checkinStart, "only may self decline after onboarding end"); // solium-disable-line security/no-block-members, max-len

        address payable speakerAddress = speakersTalks[_talkId].speakerAddress;

        require(msg.sender == speakerAddress, "only speaker may make self decline");
        require(speakersTalks[_talkId].status == ApplicationStatus.Applied, "//to do, think about self checkin or admin checkin");

        speakersTalks[_talkId].status = ApplicationStatus.Declined;

        if (speakerAddress.isContract() == false) {
            address(speakerAddress).transfer(speakersTalks[_talkId].deposit);
        }

        emit TalkSelfDeclined(_talkId);
    }

    function checkinMember(uint256 _ticketId)
        external
        duringEvent
    {
        require(membersTickets[_ticketId].bidderAddress == msg.sender, "member should make self check in");
        membersTickets[_ticketId].checkedIn = true;

        emit MemberCheckin(_ticketId);
    }

    function checkinSpeaker(uint256 _talkId)
        external
        onlyOwner
        duringEvent
    {
        require(speakersTalks[_talkId].checkedIn == false, "speaker shouldn't be checked in before");
        require(speakersTalks[_talkId].status == ApplicationStatus.Accepted, "speaker should be accepted before");

        uint256 bidId = totalSupply();
        address speakerAddress = speakersTalks[_talkId].speakerAddress;
        super._mint(speakerAddress, bidId);
        ticketByAddressIndex[speakerAddress] = bidId; //?
        speakersTalks[_talkId].checkedIn = true;

        emit SpeakerCheckin(_talkId);
    }

    function distributeOverbids(uint256 _fromBid, uint256 _toBid)
        external
        onlyOwner
        afterDistributionStart
    {
        require(_fromBid <= _toBid, "bids window should be correct");
        uint256 checkedInSpeakers = 0;
        for (uint256 y = 0; y < speakersTalks.length; y++){
            if (speakersTalks[y].checkedIn) checkedInSpeakers++;
        }
        uint256 ticketsForMembersSupply = totalSupply().sub(checkedInSpeakers);
        require(_fromBid < ticketsForMembersSupply && _toBid < ticketsForMembersSupply, "bids window should be correct");
        for (uint256 i = _fromBid; i <= _toBid; i++) {
            require(membersTickets[i].overbidReturned == false, "bid's overbid shouldn't be distrubuted yet");
            address payable bidderAddress = membersTickets[i].bidderAddress;
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

        emit OverbidsDistributed();
    }

    function distributeRewards()
        external
        onlyOwner
        afterDistributionStart
    {
        require(overbidsDistributed == true, "overbids should be disbributed before");
        if (acceptedSpeakersSlots > 0) {
            uint256 checkedInSpeakers = 0;
            for (uint256 i = 0; i < speakersTalks.length; i++){
                if (speakersTalks[i].checkedIn) checkedInSpeakers++;
            }
            uint256 valueForTicketsForReward = endPrice.mul(membersTickets.length);
            uint256 valueFromTicketsForSpeakers = valueForTicketsForReward.mul(getSpeakersShares()).div(100);

            uint256 valuePerSpeakerFromTickets = valueFromTicketsForSpeakers.div(checkedInSpeakers);
            for (uint256 y = 0; y < speakersTalks.length; y++) {
                address payable speakerAddress = speakersTalks[y].speakerAddress;
                if (speakersTalks[y].checkedIn == true && speakerAddress.isContract() == false) {
                    speakerAddress.transfer(valuePerSpeakerFromTickets.add(speakersTalks[y].deposit));
                }
            }
        }
        address(msg.sender).transfer(address(this).balance);

        emit RewardsDistributed();
    }

    function setTalksGrid(string calldata _grid)
        external
        onlyOwner
    {
        talksGrid = _grid;

        emit UpdatedTalksGrid(_grid);
    }

    function setWorkshopsGrid(string calldata _grid)
        external
        onlyOwner
    {
        workshopsGrid = _grid;

        emit UpdatedWorkshopsGrid(_grid);
    }

    function getTalkById(uint256 _id)
        external
        view
        returns(
            string memory,
            string memory,
            string memory,
            uint256,
            uint256,
            address,
            uint256,
            bool,
            ApplicationStatus,
            string memory
        )
    {
        require(_id < uint256(speakersTalks.length), "out of index of speakers");
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

    function getTicketIdByAddress(address _address)
        external
        view
        returns(uint256)
    {
        return ticketByAddressIndex[_address];
    }

    function getAuctionStartBlock()
        external
        view
        returns(uint256)
    {
        return auctionStartBlock;
    }

    function getAuctionStartTime()
        external
        view
        returns(uint256)
    {
        return auctionStartTime;
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

    function getCurrentPrice()
        public
        view
        returns(uint256)
    {
        uint256 blocksPassed = block.number - auctionStartBlock;
        uint256 currentDiscount = blocksPassed.mul(bidBlockDecrease);

        if (currentDiscount < (initialPrice - minimalPrice)) {
            return initialPrice.sub(currentDiscount);
        } else {
            return minimalPrice;
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
        view
        returns(uint256)
    {
        return minimalPrice;
    }

    function getMinimalSpeakerDeposit()
        external
        view
        returns(uint256)
    {
        return minimalSpeakerDeposit;
    }

    function getTotalTickets()
        external
        view
        returns(uint256)
    {
        return totalTickets;
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
        view
        returns(uint256)
    {
        return speakersSlots;
    }

    function getAvailableSpeaksersSlots()
        external
        view
        returns(uint256)
    {
        return speakersSlots.sub(acceptedSpeakersSlots);
    }

    function getOrganizersShares()
        public
        view
        returns(uint256)
    {
        uint256 time = auctionEnd;
        if (ticketsAmount > 0 && block.timestamp < checkinStart) { // solium-disable-line security/no-block-members
            time = block.timestamp; // solium-disable-line security/no-block-members
        }
        uint256 mul = time.sub(auctionStartTime).mul(100).div(checkinStart.sub(auctionStartTime));
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
        view
        returns(string memory)
    {
        return eventPlace;
    }

    function getDescription()
        external
        view
        returns(string memory)
    {
        return eventDescription;
    }

    function getTalksGrid()
        external
        view
        returns(string memory)
    {
        return talksGrid;
    }

    function getWorkshopsGrid()
        external
        view
        returns(string memory)
    {
        return workshopsGrid;
    }

    function getCommunityBuilderMessage(uint256 _messageID)
        external
        view
        returns(
            string memory,
            string memory,
            string memory,
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