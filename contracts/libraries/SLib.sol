// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/**
 * @title Skillon Library
 */
library SLib {
    uint256 constant DURATION_STEPSIZE = 300; // 5 minute stepsize

    enum ContestType {
        MUTUAL_AGREEMENT,
        EXACT_SCHEDULE
    }

    enum ContestState {
        ACTIVE,
        CLOSED,
        COMPLETED
    }

    struct Range {
        uint start;
        uint end;
    }

    struct Contest {
        ContestType cType;
        uint lotAmount;
        uint duration;
        uint participants;
        uint maxParticipants;
        address creator;
        Range range;
        ContestState state;
        bool _exist;
    }

    struct Participation {
        uint lotAmount;
        uint prizeAmount;
        bool isPrizeReceived;
        bool _exist;
    }

    function isInRange(Range memory range, uint point) internal pure returns (bool) {
        return ((point >= range.start && point < range.end));
    }

    function isInRange(Range memory range) internal view returns (bool) {
        return isInRange(range, block.timestamp);
    }

    function isAllowedDuration(uint duration, uint maxStep) internal pure returns (bool) {
        uint step = durationToStep(duration);
        return (step >= 1 && step <= maxStep);
    }

    function stepToDuration(uint step) internal pure returns (uint) {
        return (step * DURATION_STEPSIZE);
    }

    function durationToStep(uint duration) internal pure returns (uint) {
        return clearDust(duration, DURATION_STEPSIZE) / DURATION_STEPSIZE;
    }

    function clearDust(uint size, uint stepSize) internal pure returns (uint) {
        return (size - (size % stepSize));
    }
}
