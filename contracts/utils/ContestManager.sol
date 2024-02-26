// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../abstract/ManagerAccess.sol";
import "../abstract/DepositWithdraw.sol";
import "./../libraries/SLib.sol";
import "./../interfaces/ITokenDistributionManager.sol";

contract ContestManager is Ownable, ManagerAccess, DepositWithdraw {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    uint256 constant MAX_INT = 2 ** 256 - 1;
    uint16 constant MAX_PRIZE_COMMISSION_PERCENTAGE = 200; // %20 percentage

    // Address of the ERC20 token
    IERC20 public immutable token;
    ITokenDistributionManager private _distributionManager;

    // Prize commission percentage (100 -> %10)
    uint16 public prizeCommissionPercentage;

    //BEGIN: CONTEST VARIABLES
    // Minimum lot amount for contest creation
    uint public minimumLotAmount = 10 ** 18;
    // Lot amount step size (0.1 Token in default)
    uint public lotAmountStepSize = 10 ** 17;
    // Maximum number of participation on a single contest
    uint public maxParticipationCount = 20;
    // Maximum stepsize for contest duration (1 Step = 300 Seconds = 5 Minutes)
    uint private _maxStepSize = 6;
    // Contest counter
    Counters.Counter private _contestCounter;
    // Mapping of contests (ContestID > Contest)
    mapping(uint => SLib.Contest) public contest;
    // Contest prize pool (ContestID > Pool Total)
    mapping(uint => uint) public contestPrizePool;
    // Contest participations (Address > ContestID > Participation)
    mapping(address => mapping(uint => SLib.Participation)) public contestParticipation;
    //END: CONTEST VARIABLES

    // EVENTS
    event PrizeCommissionUpdated(uint16 old, uint16 current);
    event DurationMaximumStepSizeUpdated(uint oldStepSize, uint newStepSize, uint durationInSeconds);
    event MaximumParticipationUpdated(uint oldMaxParticipation, uint maxParticipation);
    event LotAmountStepSizeUpdated(uint oldLotAmountStepSize, uint lotAmountStepSize);
    event MinimumLotAmountUpdated(uint oldAmount, uint amount);
    event DistributionManagerUpdated(address oldAddress, address newAddress);

    event NewContest(address indexed creator, uint contestID, SLib.ContestType contestType, uint lotAmount, uint maxParticipants, uint duration, uint start, uint end);
    event NewContestParticipation(address indexed participant, uint contestId, uint lotAmount, bool isCreator);
    event ContestIsCompleted(uint contestID, uint totalPrizePool, uint commission);
    event ContestClosed(uint contestID);
    event MutualContestStarted(uint contestID, uint start, uint end);

    // MODIFIERS
    modifier onlyManagerDefined() {
        require(address(_distributionManager) != address(0), "Distribution manager is not defined");
        _;
    }

    constructor(address token_){
        // Check that the token address is not 0x0.
        require(token_ != address(0x0));
        // Set the token address.
        token = IERC20(token_);
        // Set default prize commission percentage (%15 in default)
        prizeCommissionPercentage = 150;
    }

    function _thousandRatio(uint value, uint16 ratio) internal pure returns (uint, uint) {
        require(ratio < 1000, "Ratio: Ratio should lower than thousand");
        uint piece = value * ratio / 1000;
        return (piece, value - piece);
    }

    function nextContestID() external view returns (uint) {
        return (_contestCounter.current() + 1);
    }

    function maximumContestDuration() external view returns (uint) {
        return SLib.stepToDuration(_maxStepSize);
    }

    function contestCount() external view returns (uint) {
        return _contestCounter.current();
    }

    function setMinimumLotAmount(uint minAmount) external onlyOwnerOrManager {
        require(
            minAmount > 0 &&
            minAmount > lotAmountStepSize &&
            (minAmount % lotAmountStepSize) == 0,
            "Wrong minimum lot amount"
        );
        uint oldAmount = minimumLotAmount;
        require(minAmount != oldAmount, "Nothing changed");
        emit MinimumLotAmountUpdated(oldAmount, minAmount);
    }

    function setLotAmountStepSize(uint stepSize) external onlyOwnerOrManager {
        uint oldStepSize = lotAmountStepSize;
        require(stepSize > 0, "Step size should be higher");
        require(stepSize != oldStepSize, "Nothing changed");
        lotAmountStepSize = stepSize;
        emit LotAmountStepSizeUpdated(oldStepSize, stepSize);
    }

    function setMaximumParticipation(uint maxParticipation) external onlyOwnerOrManager {
        uint oldMaxParticipation = maxParticipationCount;
        require(maxParticipation > 1, "Should higher than 1");
        require(maxParticipation != oldMaxParticipation, "Nothing changed");
        maxParticipationCount = maxParticipation;
        emit MaximumParticipationUpdated(oldMaxParticipation, maxParticipation);
    }

    function setDurationMaximumStepSize(uint maxStepSize) external onlyOwnerOrManager {
        uint oldStepSize = _maxStepSize;
        require(maxStepSize >= 6, "Max stepsize should be higher than 6");
        require(maxStepSize != oldStepSize, "Nothing changed");
        _maxStepSize = maxStepSize;
        emit DurationMaximumStepSizeUpdated(oldStepSize, maxStepSize, SLib.stepToDuration(maxStepSize));
    }

    function setPrizeCommissionPercentage(uint16 percentage) external onlyOwnerOrManager {
        require(percentage <= MAX_PRIZE_COMMISSION_PERCENTAGE, "Prize percentage is too high");
        uint16 oldPercentage = prizeCommissionPercentage;
        prizeCommissionPercentage = percentage;
        emit PrizeCommissionUpdated(oldPercentage, percentage);
    }

    function setDistributionManager(address distributionManager) public onlyOwnerOrManager {
        require(distributionManager != address(0), "Manager cant be zero address");
        require(distributionManager != address(_distributionManager), "Nothing changed");
        address oldAddress = address(_distributionManager);

        _distributionManager = ITokenDistributionManager(distributionManager);
        emit DistributionManagerUpdated(oldAddress, distributionManager);
    }

    function _joinContest(uint contestID, address participant, uint lotAmount, bool isCreator, bool isContestStartsNow) internal {
        // Transfer token
        token.safeTransferFrom(participant, address(this), lotAmount);
        // Increase participation counter
        contest[contestID].participants += 1;
        // Increase prize pool
        contestPrizePool[contestID] += lotAmount;
        // Set participation state
        contestParticipation[participant][contestID] = SLib.Participation(lotAmount, 0, false, true);
        // Emit participation event
        emit NewContestParticipation(_msgSender(), contestID, lotAmount, isCreator);
        // Set contest time-range & state if it starts now
        if (isContestStartsNow) {
            uint endTime = (block.timestamp + contest[contestID].duration);
            contest[contestID].range = SLib.Range(block.timestamp, endTime);
            emit MutualContestStarted(contestID, block.timestamp, endTime);
        }
    }

    function createContest(SLib.ContestType contestType, uint maxParticipants, uint duration, uint lotAmount, uint startDateTimestamp) external onlyManagerDefined {
        require(SLib.isAllowedDuration(duration, _maxStepSize), "Contest duration is not correct");
        require(maxParticipants >= 2 && maxParticipants <= maxParticipationCount);
        lotAmount = SLib.clearDust(lotAmount, lotAmountStepSize);
        require(lotAmount >= minimumLotAmount, "Lot amount should be higher");

        SLib.Range memory contestRange = SLib.Range(0, 0);

        if (contestType == SLib.ContestType.EXACT_SCHEDULE) {
            require(startDateTimestamp > 0 && startDateTimestamp > block.timestamp, "Start date should be higher");
            // Start at given date
            contestRange.start = startDateTimestamp;
            // Contest end given duration
            contestRange.end = startDateTimestamp + duration;
        }

        // Get new contest id
        _contestCounter.increment();
        uint contestID = _contestCounter.current();
        SLib.Contest memory _newContest = SLib.Contest(
            contestType,
            lotAmount,
            duration,
            0,
            maxParticipants,
            _msgSender(),
            contestRange,
            SLib.ContestState.ACTIVE,
            true
        );

        // Create contest & Participation
        contest[contestID] = _newContest;

        emit NewContest(_msgSender(), contestID, contestType, lotAmount, maxParticipants, duration, contestRange.start, contestRange.end);
        _joinContest(contestID, _msgSender(), lotAmount, true, false);
    }

    function _canJoinContest(SLib.Contest memory _contest, address participant) internal view returns (bool) {
        // Participant is owner of this contest
        if (_contest.creator == participant) {
            return false;
        }
        // Contest is full
        if (_contest.maxParticipants == _contest.participants) {
            return false;
        }
        if (_contest.cType == SLib.ContestType.EXACT_SCHEDULE) {
            // Can't join if contest is started
            if (SLib.isInRange(_contest.range, block.timestamp)) {
                return false;
            }
        }
        if (_contest.state == SLib.ContestState.CLOSED) {
            // Contest closed
            return false;
        }
        return true;
    }

    function canJoinContest(uint contestID, address account) external view returns (bool) {
        SLib.Contest memory _contest = contest[contestID];
        return (_contest._exist == false ? false : _canJoinContest(_contest, account));
    }

    function joinContest(uint contestID) public onlyManagerDefined {
        SLib.Contest memory _contest = contest[contestID];
        require(_contest._exist, "Contest does not exist");
        require(_canJoinContest(_contest, _msgSender()), "You cant join this contest");
        bool isContestStartsNow = (_contest.cType == SLib.ContestType.MUTUAL_AGREEMENT && (_contest.participants + 1) == _contest.maxParticipants);

        _joinContest(contestID, _msgSender(), _contest.lotAmount, false, isContestStartsNow);
    }

    function closeContest(uint contestID) public {
        SLib.Contest memory _contest = contest[contestID];
        require(_contest._exist, "Contest does not exist");
        require(_contest.creator == _msgSender(), "You are not creator of this contest");
        require(_contest.participants == 1, "Cannot close participated contest");
        require(_contest.state == SLib.ContestState.ACTIVE, "Contest is not active");

        SLib.Participation memory prt = contestParticipation[_msgSender()][contestID];
        require(prt._exist, "Not participated");

        // Update contest state
        contest[contestID].state = SLib.ContestState.CLOSED;

        // Transfer user tokens
        token.safeTransfer(_msgSender(), prt.lotAmount);

        emit ContestClosed(contestID);
    }

    function setContestWinners(uint contestID, address[] calldata winners, uint16[] calldata prizeRatios) public onlyOwnerOrManager onlyManagerDefined {
        // Contest validations
        SLib.Contest memory _contest = contest[contestID];
        require(_contest._exist, "Contest does not exist");
        require(_contest.state == SLib.ContestState.ACTIVE, "Contest is not active");
        if (_contest.cType == SLib.ContestType.EXACT_SCHEDULE) {
            require(!SLib.isInRange(_contest.range, block.timestamp), "Contest duration is not completed yet");
        }

        // Arguments validation
        uint len = winners.length;
        uint16 totalRatio = 0;
        require(len == prizeRatios.length, "Argument lengths does not match");
        require(len > 0, "Define a winner");
        for (uint256 i = 0; i < len; i++) {
            require(prizeRatios[i] > 0, "Wrong winner prize ratio");
            totalRatio += prizeRatios[i];
        }
        require(totalRatio == 100, "Prize totals should be hundred percentage");

        // Calculate commission & prize distribution amount
        uint pool = contestPrizePool[contestID];
        (uint commission, uint totalPrize) = _thousandRatio(pool, prizeCommissionPercentage);

        // Contest state update
        contest[contestID].state = SLib.ContestState.COMPLETED;

        // Check winners & Send their prize tokens
        for (uint256 i = 0; i < len; i++) {
            address winner = winners[i];
            SLib.Participation storage prt = contestParticipation[winner][contestID];
            require(prt._exist, "Winner dont participated this contest");
            uint winnerPrize = totalPrize * prizeRatios[i] / 100;

            // Update participation states
            prt.isPrizeReceived = true;
            prt.prizeAmount = winnerPrize;

            // Send prize tokens to winner
            token.safeTransfer(winner, winnerPrize);
        }

        // Commission send & distribution
        if (commission > 0) {
            // Transfer commission into the distribution manager
            token.safeTransfer(address(_distributionManager), commission);

            // Call distribution method
            _distributionManager.distribute(commission);
        }

        emit ContestIsCompleted(contestID, pool, commission);
    }
}
