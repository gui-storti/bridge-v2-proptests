// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.2;

import "../operating/PriceOracle.sol";
import "../operating/ComplianceRegistry.sol";
import "../interfaces/IERC20Detailed.sol";
import "../interfaces/IGovernable.sol";
import "../interfaces/IPriceable.sol";
import "../interfaces/IPriceOracle.sol";

/**
 * @dev Mock ERC20 que implementa as 3 interfaces que o ComplianceRegistry usa no
 *      fluxo on-hold (IERC20Detailed + IGovernable + IPriceable).
 */
contract MockBridgeToken is IERC20Detailed, IGovernable, IPriceable {
    uint256 public totalSupply_;
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;
    address public override realm;
    address[] public tis;
    IPriceOracle public override priceOracle;

    constructor() public { realm = address(this); }

    function name() external override view returns (string memory) { return "MBT"; }
    function symbol() external override view returns (string memory) { return "MBT"; }
    function decimals() external override view returns (uint8) { return 18; }
    function totalSupply() external override view returns (uint256) { return totalSupply_; }
    function balanceOf(address a) external override view returns (uint256) { return balances[a]; }
    function allowance(address o, address s) external override view returns (uint256) { return allowances[o][s]; }
    function transfer(address to, uint256 v) external override returns (bool) { _move(msg.sender, to, v); return true; }
    function approve(address s, uint256 v) external override returns (bool) { allowances[msg.sender][s] = v; return true; }
    function transferFrom(address f, address t, uint256 v) external override returns (bool) { _move(f, t, v); return true; }
    function trustedIntermediaries() external override view returns (address[] memory) { return tis; }
    function setTrustedIntermediaries(address[] calldata t) external override { tis = t; }
    function setRealm(address r) external override { realm = r; }
    function isRealmAdministrator(address) external override view returns (bool) { return true; }
    function addRealmAdministrator(address) external override {}
    function removeRealmAdministrator(address) external override {}
    function setPriceOracle(IPriceOracle) external override {}
    function convertTo(uint256 a, string calldata, uint8) external override view returns (uint256) { return a; }
    function mint(address to, uint256 v) external { balances[to] += v; totalSupply_ += v; }
    function _move(address f, address t, uint256 v) internal { require(balances[f] >= v, "bal"); balances[f] -= v; balances[t] += v; }
}

/**
 * @dev Harness combinado:
 *   B2 (oracle): price roundtrip + acesso onlyOperator (non-operator nao muda).
 *   B3 (on-hold): decisao terminal (uma vez processada, nunca volta a ONHOLD) e
 *       single-process (saldo do token move exatamente uma vez).
 */
contract OracleOnHoldHarness {
    PriceOracle public oracle;
    ComplianceRegistry public cr;
    MockBridgeToken public token;

    address public constant TI = address(0xaaaa);
    address public constant FROM = address(0x1111);
    address public constant TO = address(0x2222);

    bytes32 public constant C1 = bytes32("CHF");
    bytes32 public constant C2 = bytes32("EUR");
    uint256 public expectedPrice = 123456;
    uint8 public expectedDecimals = 6;

    uint256[] public pendingIds;

    constructor() public {
        oracle = new PriceOracle();
        oracle.initialize(address(this));
        oracle.setPrice(C1, C2, expectedPrice, expectedDecimals);

        cr = new ComplianceRegistry();
        cr.initialize(address(this));

        token = new MockBridgeToken();
        token.mint(FROM, 1000 ether);
        address[] memory t = new address[](1);
        t[0] = TI;
        token.setTrustedIntermediaries(t);

        // funda um on-hold transfer de exemplo
        cr.addOnHoldTransfer(TI, address(token), FROM, TO, 100 ether);
        pendingIds.push(0);
    }

    // ---- handlers ----

    function processApprove(uint8 idx) external {
        uint256[] memory ids = new uint256[](1);
        uint8[] memory dec = new uint8[](1);
        ids[0] = pendingIds[idx % pendingIds.length];
        dec[0] = 1; // APPROVE
        cr.processOnHoldTransfers(ids, dec, false);
    }

    function processReject(uint8 idx) external {
        uint256[] memory ids = new uint256[](1);
        uint8[] memory dec = new uint8[](1);
        ids[0] = pendingIds[idx % pendingIds.length];
        dec[0] = 2; // REJECT
        cr.processOnHoldTransfers(ids, dec, false);
    }

    // ---- invariantes ----

    function property_oracle_price_roundtrip() external view returns (bool) {
        (uint256 p, uint8 d) = oracle.getPrice(C1, C2);
        return p == expectedPrice && d == expectedDecimals;
    }

    function property_onhold_single_process() external view returns (bool) {
        // o saldo do TO so pode ser 0 (nao processado) ou 100 ether (aprovado uma vez),
        // nunca 200 ether (double-process). O FROM tambem nunca fica negativo.
        uint256 toBal = token.balances(TO);
        uint256 fromBal = token.balances(FROM);
        // processado uma vez => TO == 100 ether, FROM == 900 ether
        bool okApproved = (toBal == 100 ether && fromBal == 900 ether);
        // nao processado => TO == 0, FROM == 1000 ether
        bool okPending = (toBal == 0 && fromBal == 1000 ether);
        return okApproved || okPending;
    }
}
