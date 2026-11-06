// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.2;

import "../rules/UserValidRule.sol";
import "../rules/UserFreezeRule.sol";
import "../rules/VestingRule.sol";
import "../rules/HardTransferLimitRule.sol";
import "./mocks/MockToken.sol";
import "./mocks/MockComplianceRegistry.sol";

/**
 * @dev Harnesses for the compliance rules that read the ComplianceRegistry +
 *      token interfaces. Each harness deploys a MockToken + MockComplianceRegistry,
 *      registers users with controlled attributes, and checks that the rule
 *      rejects/accepts transfers exactly according to the configured state.
 */

contract UserValidRuleProptest is UserValidRule {
    MockToken public token;
    MockComplianceRegistry public registry;
    address public from;
    address public to;
    uint256 public flag;

    constructor() public {
        token = new MockToken();
        registry = new MockComplianceRegistry();
        initialize(IComplianceRegistry(address(registry)));
    }

    function setFrom(address a) external { from = a; }
    function setTo(address a) external { to = a; }
    function setFlag(uint256 f) external { flag = f; }
    function setValid(address a, bool v) external { registry.setValid(a, v); }

    function echidna_user_valid() external view returns (bool) {
        (uint256 status, ) = isTransferValid(address(token), from, to, 0, flag);
        bool fromValid = registry.validOf(from);
        bool toValid = registry.validOf(to);
        bool expected;
        if (flag > USER_VALID_FLAG_TO) {
            expected = false;
        } else if (flag == USER_VALID_FLAG_FROM) {
            expected = fromValid;
        } else if (flag == USER_VALID_FLAG_TO) {
            expected = toValid;
        } else {
            expected = fromValid && toValid;
        }
        return (status == TRANSFER_VALID_WITH_NO_HOOK) == expected;
    }

    function check_user_valid(address a, address b, uint256 f) external view {
        (uint256 status, ) = isTransferValid(address(token), a, b, 0, f);
        bool fromValid = registry.validOf(a);
        bool toValid = registry.validOf(b);
        bool expected;
        if (f > USER_VALID_FLAG_TO) {
            expected = false;
        } else if (f == USER_VALID_FLAG_FROM) {
            expected = fromValid;
        } else if (f == USER_VALID_FLAG_TO) {
            expected = toValid;
        } else {
            expected = fromValid && toValid;
        }
        assert((status == TRANSFER_VALID_WITH_NO_HOOK) == expected);
    }
}

contract UserFreezeRuleProptest is UserFreezeRule {
    MockToken public token;
    MockComplianceRegistry public registry;
    address public frozenUser;
    address public normalUser;
    address public from;
    address public to;

    uint256 private constant KEY_DIRECTION = 120;
    uint256 private constant KEY_START = 121;
    uint256 private constant KEY_END = 122;
    uint256 private constant KEY_INVERTED = 123;

    constructor() public {
        token = new MockToken();
        registry = new MockComplianceRegistry();
        initialize(IComplianceRegistry(address(registry)));

        frozenUser = address(0xaaaa);
        normalUser = address(0xbbbb);

        // frozenUser: send-freeze active now (direction SEND, start 0, end max, not inverted)
        registry.setUser(frozenUser, 1, address(0));
        registry.setAttr(address(0), 1, KEY_DIRECTION, 2);
        registry.setAttr(address(0), 1, KEY_START, 0);
        registry.setAttr(address(0), 1, KEY_END, uint256(-1));
        registry.setAttr(address(0), 1, KEY_INVERTED, 0);

        // normalUser: no freeze
        registry.setUser(normalUser, 2, address(0));
        registry.setAttr(address(0), 2, KEY_DIRECTION, 0);
    }

    function echidna_frozen_send_rejected() external view returns (bool) {
        // A send-frozen user must be rejected as the `from` of a transfer.
        (uint256 status, uint256 reason) = isTransferValid(address(token), frozenUser, normalUser, 1, 0);
        return status == TRANSFER_INVALID && reason == 2;
    }
}

contract VestingRuleProptest is VestingRule {
    MockToken public token;
    MockComplianceRegistry public registry;
    address public from;
    address public to;
    uint256 public timestamp;

    constructor() public {
        token = new MockToken();
        registry = new MockComplianceRegistry();
        initialize(IComplianceRegistry(address(registry)));
    }

    function setFrom(address a) external { from = a; }
    function setTo(address a) external { to = a; }
    function setTimestamp(uint256 t) external { timestamp = t; }
    function setBypass(address user, uint256 uid, uint256 direction) external {
        registry.setUser(user, uid, address(0));
        registry.setAttr(address(0), uid, BYPASS_KEY, direction);
    }

    function echidna_vesting_frozen() external view returns (bool) {
        (uint256 status, ) = isTransferValid(address(token), from, to, 0, timestamp);
        if (timestamp <= block.timestamp) {
            return status == TRANSFER_VALID_WITH_NO_HOOK;
        }
        if (from == token.owner()) {
            return status == TRANSFER_VALID_WITH_NO_HOOK;
        }
        uint256 fromKey = _bypass(from);
        uint256 toKey = _bypass(to);
        bool allowed;
        if (fromKey == INTERNAL_USER_NOT_FOUND || toKey == INTERNAL_USER_NOT_FOUND) {
            allowed = false;
        } else {
            // valid iff from has SEND(2)/BOTH(3)+ (not NONE/RECEIVE) and to has
            // RECEIVE(1)/BOTH(3)+ (not NONE/SEND)
            allowed = (fromKey != BYPASS_DIRECTION_NONE && fromKey != BYPASS_DIRECTION_RECEIVE) &&
                      (toKey != BYPASS_DIRECTION_NONE && toKey != BYPASS_DIRECTION_SEND);
        }
        return (status == TRANSFER_VALID_WITH_NO_HOOK) == allowed;
    }

    function _bypass(address a) internal view returns (uint256) {
        (uint256 uid, address ti) = registry.userId(new address[](0), a);
        if (uid == 0) return INTERNAL_USER_NOT_FOUND;
        return registry.attrOf(keccak256(abi.encodePacked(ti, uid, BYPASS_KEY)));
    }
}

contract HardTransferLimitRuleProptest is HardTransferLimitRule {
    MockToken public token;
    MockComplianceRegistry public registry;
    address public constant FROM = address(0x1234);
    address public constant TO = address(0x5678);
    uint256 public amount;

    uint256 private constant KEY_SINGLE = 110;
    uint256 private constant KEY_MONTHLY = 111;
    uint256 private constant KEY_YEARLY = 112;
    uint256 private constant HIGH = 10**30;   // high enough to never trigger monthly/yearly

    constructor() public {
        token = new MockToken();
        token.setConvertToMultiplier(1);
        registry = new MockComplianceRegistry();
        initialize(address(this), IComplianceRegistry(address(registry)));

        registry.setUser(FROM, 1, address(0));
        registry.setAttr(address(0), 1, KEY_SINGLE, HIGH);
        registry.setAttr(address(0), 1, KEY_MONTHLY, HIGH);
        registry.setAttr(address(0), 1, KEY_YEARLY, HIGH);

        registry.setUser(TO, 2, address(0));
        registry.setAttr(address(0), 2, KEY_SINGLE, HIGH);
        registry.setAttr(address(0), 2, KEY_MONTHLY, HIGH);
        registry.setAttr(address(0), 2, KEY_YEARLY, HIGH);
    }

    function setAmount(uint256 a) external { require(a <= 10**70, "amount bound"); amount = a; }
    function setFromSingle(uint256 t) external {
        require(t <= HIGH, "threshold bound");
        registry.setAttr(address(0), 1, KEY_SINGLE, t);
    }

    function echidna_single_transfer_limit() external view returns (bool) {
        (uint256 status, ) = isTransferValid(address(token), FROM, TO, amount, 0);
        uint256 single = registry.attrOf(keccak256(abi.encodePacked(address(0), uint256(1), KEY_SINGLE)));
        uint256 scaled = single * 10**40;   // safe: single <= 10^30 => scaled <= 10^70
        if (amount > scaled) {
            return status == TRANSFER_INVALID;
        }
        return status == TRANSFER_VALID_WITH_AFTER_HOOK;
    }
}
