// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.2;

import "../rules/MinTransferRule.sol";
import "../rules/MaxTransferRule.sol";
import "../rules/YesNoRule.sol";
import "../rules/YesNoUpdateRule.sol";
import "../rules/GlobalFreezeRule.sol";

/**
 * @dev Property harnesses for the pure, no-dependency transfer rules.
 *      Each `echidna_*` function is fuzzed by echidna (state mutated via the
 *      setters); each `check_*` function is symbolically executed by halmos
 *      (parameters made symbolic) with an `assert` on the rule's contract.
 */
contract MinTransferRuleProptest is MinTransferRule {
    uint256 public amount;
    uint256 public minAmount;
    address public constant TOKEN = address(0x1);

    function setAmount(uint256 a) external { amount = a; }
    function setMinAmount(uint256 m) external { minAmount = m; }

    function echidna_min_threshold() external view returns (bool) {
        (uint256 status, ) = isTransferValid(TOKEN, address(0), address(0), amount, minAmount);
        return (status == TRANSFER_VALID_WITH_NO_HOOK) == (amount >= minAmount);
    }

    function check_min_threshold(uint256 a, uint256 m) external view {
        (uint256 status, ) = isTransferValid(TOKEN, address(0), address(0), a, m);
        assert((status == TRANSFER_VALID_WITH_NO_HOOK) == (a >= m));
    }
}

contract MaxTransferRuleProptest is MaxTransferRule {
    uint256 public amount;
    uint256 public maxAmount;
    address public constant TOKEN = address(0x1);

    function setAmount(uint256 a) external { amount = a; }
    function setMaxAmount(uint256 m) external { maxAmount = m; }

    function echidna_max_threshold() external view returns (bool) {
        (uint256 status, ) = isTransferValid(TOKEN, address(0), address(0), amount, maxAmount);
        return (status == TRANSFER_VALID_WITH_NO_HOOK) == (amount <= maxAmount);
    }

    function check_max_threshold(uint256 a, uint256 m) external view {
        (uint256 status, ) = isTransferValid(TOKEN, address(0), address(0), a, m);
        assert((status == TRANSFER_VALID_WITH_NO_HOOK) == (a <= m));
    }
}

contract YesNoRuleProptest is YesNoRule {
    uint256 public yesNo;
    address public constant TOKEN = address(0x1);

    function setYesNo(uint256 y) external { yesNo = y; }

    function echidna_yesno() external view returns (bool) {
        (uint256 status, ) = isTransferValid(TOKEN, address(0), address(0), 0, yesNo);
        return (status == TRANSFER_VALID_WITH_NO_HOOK) == (yesNo > 0);
    }

    function check_yesno(uint256 y) external view {
        (uint256 status, ) = isTransferValid(TOKEN, address(0), address(0), 0, y);
        assert((status == TRANSFER_VALID_WITH_NO_HOOK) == (y > 0));
    }
}

contract YesNoUpdateRuleProptest is YesNoUpdateRule {
    uint256 public yesNo;
    address public constant TOKEN = address(0x1);

    constructor() public { initialize(); }

    function setYesNo(uint256 y) external { yesNo = y; }

    function echidna_yesno_update() external view returns (bool) {
        (uint256 status, ) = isTransferValid(TOKEN, address(0), address(0), 0, yesNo);
        // YesNoUpdateRule returns AFTER_HOOK (3) when yesNo > 0, INVALID (0) otherwise.
        return (status == TRANSFER_VALID_WITH_AFTER_HOOK) == (yesNo > 0);
    }
}

contract GlobalFreezeRuleProptest is GlobalFreezeRule {
    address public constant TOKEN = address(0x1);

    constructor() public { initialize(address(this)); }

    function setFrozenUntil(uint256 u) external { allFrozenUntil = u; }

    function echidna_global_freeze() external view returns (bool) {
        (uint256 status, ) = isTransferValid(TOKEN, address(0), address(0), 0, 0);
        bool frozen = _isFrozen();
        return frozen == (status == TRANSFER_INVALID);
    }
}
