// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.2;

import "../../interfaces/IComplianceRegistry.sol";

/**
 * @dev Settable IComplianceRegistry mock. The property-test harnesses configure
 *      user ids, attributes, validity and transfer counters through the setXxx
 *      functions, then the compliance rules read them through the interface.
 */
contract MockComplianceRegistry is IComplianceRegistry {
    mapping(address => uint256) public userOf;          // address -> userId
    mapping(address => address) public tiOf;            // address -> trustedIntermediary
    mapping(bytes32 => uint256) public attrOf;          // keccak(ti,userId,key) -> value
    mapping(address => bool) public validOf;            // address -> validity
    mapping(bytes32 => uint256) public transferOf;      // keccak(realm,kind,address) -> amount

    uint8 private constant KIND_MONTHLY_IN = 1;
    uint8 private constant KIND_YEARLY_IN = 2;
    uint8 private constant KIND_MONTHLY_OUT = 3;
    uint8 private constant KIND_YEARLY_OUT = 4;

    // ---- setters (used by harnesses) ----
    function setUser(address a, uint256 uid, address ti) external {
        userOf[a] = uid;
        tiOf[a] = ti;
    }
    function setAttr(address ti, uint256 uid, uint256 key, uint256 value) external {
        attrOf[keccak256(abi.encodePacked(ti, uid, key))] = value;
    }
    function setValid(address a, bool v) external {
        validOf[a] = v;
    }
    function setTransfer(address realm, uint8 kind, address a, uint256 value) external {
        transferOf[keccak256(abi.encodePacked(realm, kind, a))] = value;
    }

    // ---- IComplianceRegistry (view) ----
    function userId(address[] calldata, address _address)
        external override view returns (uint256, address)
    {
        return (userOf[_address], tiOf[_address]);
    }

    function validUntil(address, uint256) external override view returns (uint256) {
        return uint256(-1);
    }

    function attribute(address _ti, uint256 _userId, uint256 _key)
        external override view returns (uint256)
    {
        return attrOf[keccak256(abi.encodePacked(_ti, _userId, _key))];
    }

    function attributes(address _ti, uint256 _userId, uint256[] calldata _keys)
        external override view returns (uint256[] memory)
    {
        uint256[] memory vals = new uint256[](_keys.length);
        for (uint256 i = 0; i < _keys.length; i++) {
            vals[i] = attrOf[keccak256(abi.encodePacked(_ti, _userId, _keys[i]))];
        }
        return vals;
    }

    function isAddressValid(address[] calldata, address _address)
        external override view returns (bool)
    {
        return validOf[_address];
    }

    function isValid(address, uint256) external override view returns (bool) {
        return true;
    }

    function monthlyTransfers(address, address[] calldata, address) external override view returns (uint256) { return 0; }
    function yearlyTransfers(address, address[] calldata, address) external override view returns (uint256) { return 0; }

    function monthlyInTransfers(address _realm, address[] calldata, address _address)
        external override view returns (uint256)
    {
        return transferOf[keccak256(abi.encodePacked(_realm, KIND_MONTHLY_IN, _address))];
    }
    function yearlyInTransfers(address _realm, address[] calldata, address _address)
        external override view returns (uint256)
    {
        return transferOf[keccak256(abi.encodePacked(_realm, KIND_YEARLY_IN, _address))];
    }
    function monthlyOutTransfers(address _realm, address[] calldata, address _address)
        external override view returns (uint256)
    {
        return transferOf[keccak256(abi.encodePacked(_realm, KIND_MONTHLY_OUT, _address))];
    }
    function yearlyOutTransfers(address _realm, address[] calldata, address _address)
        external override view returns (uint256)
    {
        return transferOf[keccak256(abi.encodePacked(_realm, KIND_YEARLY_OUT, _address))];
    }

    // ---- IComplianceRegistry (mutating, mostly stubs) ----
    function registerUser(address _address, uint256[] calldata _keys, uint256[] calldata _values)
        external override
    {
        userOf[_address] = 1;
        for (uint256 i = 0; i < _keys.length; i++) {
            attrOf[keccak256(abi.encodePacked(address(0), uint256(1), _keys[i]))] = _values[i];
        }
    }
    function registerUsers(address[] calldata, uint256[] calldata, uint256[] calldata) external override {}
    function attachAddress(uint256, address) external override {}
    function attachAddresses(uint256[] calldata, address[] calldata) external override {}
    function detachAddress(address) external override {}
    function detachAddresses(address[] calldata) external override {}
    function updateUserAttributes(uint256, uint256[] calldata, uint256[] calldata) external override {}
    function updateUsersAttributes(uint256[] calldata, uint256[] calldata, uint256[] calldata) external override {}

    function updateTransfers(address _realm, address _from, address _to, uint256 _value) external override {
        // increment out counter for from, in counter for to
        bytes32 outKey = keccak256(abi.encodePacked(_realm, KIND_MONTHLY_OUT, _from));
        bytes32 inKey = keccak256(abi.encodePacked(_realm, KIND_MONTHLY_IN, _to));
        transferOf[outKey] = transferOf[outKey] + _value;
        transferOf[inKey] = transferOf[inKey] + _value;
    }

    function addOnHoldTransfer(address, address, address, address, uint256) external override {}
    function getOnHoldTransfers(address)
        external override view returns (uint256, uint256[] memory, address[] memory, address[] memory, address[] memory, uint256[] memory)
    {
        uint256[] memory a = new uint256[](0);
        address[] memory b = new address[](0);
        return (0, a, b, b, b, a);
    }
    function processOnHoldTransfers(uint256[] calldata, uint8[] calldata, bool) external override {}
    function updateOnHoldMinBoundary(uint256) external override {}
}
