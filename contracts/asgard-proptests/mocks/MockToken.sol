// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.2;

import "../../interfaces/IGovernable.sol";
import "../../interfaces/IPriceable.sol";
import "../../interfaces/IOwnable.sol";
import "../../interfaces/IPriceOracle.sol";

/**
 * @dev Minimal IGovernable + IPriceable + IOwnable mock used to satisfy the
 *      token interface that the compliance rules read from.
 */
contract MockToken is IGovernable, IPriceable, IOwnable {
    address public override owner;
    address public override realm;
    address[] private _tis;
    IPriceOracle public override priceOracle;
    uint256 public convertToMultiplier = 1;

    constructor() public {
        owner = msg.sender;
        realm = address(this);
    }

    // IGovernable
    function trustedIntermediaries() external override view returns (address[] memory) { return _tis; }
    function setTrustedIntermediaries(address[] calldata tis) external override { _tis = tis; }
    function setRealm(address r) external override { realm = r; }
    function isRealmAdministrator(address) external override view returns (bool) { return true; }
    function addRealmAdministrator(address) external override {}
    function removeRealmAdministrator(address) external override {}

    // IPriceable
    function setPriceOracle(IPriceOracle) external override {}
    function setConvertToMultiplier(uint256 m) external { convertToMultiplier = m; }
    function convertTo(uint256 _amount, string calldata, uint8) external override view returns (uint256) {
        return _amount * convertToMultiplier;
    }

    // IOwnable
    function transferOwnership(address _newOwner) external override returns (bool) { owner = _newOwner; return true; }
    function renounceOwnership() external override returns (bool) { owner = address(0); return true; }
}
