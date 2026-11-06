// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.2;

import "../operating/Processor.sol";
import "../operating/RuleEngine.sol";
import "../operating/ComplianceRegistry.sol";
import "../interfaces/IRuleEngine.sol";
import "../token/BridgeToken.sol";

/**
 * @dev Harness integrado (stack completo) para a invariante crítica de security
 *      token: CONSERVAÇÃO DE SUPPLY.
 *
 *      totalSupply == Σ balanceOf() deve valer após qualquer sequência de
 *      mint/burn/seize/transfer, porque a contabilidade real vive no Processor
 *      (_tokens[token].totalSupply e .balances), não no token.
 *
 *      Handlers (chamadas pelo Medusa/Foundry com argumentos fuzzed) restringem
 *      as operações a um conjunto fixo de contas, permitindo somar os saldos.
 */
contract SupplyConservationHarness {
    BridgeToken public token;
    Processor public processor;
    address[3] public accounts;

    constructor() public {
        ComplianceRegistry cr = new ComplianceRegistry();
        RuleEngine re = new RuleEngine();
        processor = new Processor();
        token = new BridgeToken();

        cr.initialize(address(this));
        re.initialize(address(this));
        processor.initialize(address(this), IRuleEngine(address(re)));

        address[] memory tis = new address[](0);
        token.initialize(address(this), processor, "TestToken", "TST", 18, tis);

        // o harness é owner => pode adicionar supplier/seizer
        token.addSupplier(address(this));
        token.addSeizer(address(this));

        accounts = [address(0x1111), address(0x2222), address(0x3333)];
    }

    // ---- handlers (alvos do fuzzer) ----

    function mintSelf(uint256 amount) external {
        token.mint(address(this), amount);       // supply+, harness+
    }

    function mintTo(uint8 idx, uint256 amount) external {
        token.mint(accounts[idx % 3], amount);   // supply+, account+
    }

    function burnSelf(uint256 amount) external {
        token.burn(address(this), amount);       // supply-, harness-
    }

    function burnFrom(uint8 idx, uint256 amount) external {
        token.burn(accounts[idx % 3], amount);   // supply-, account-
    }

    function transferTo(uint8 idx, uint256 amount) external {
        token.transfer(accounts[idx % 3], amount); // harness- , account+ (supply igual)
    }

    function seizeFrom(uint8 idx, uint256 amount) external {
        token.seize(accounts[idx % 3], amount);  // account- , harness+ (supply igual)
    }

    // ---- invariante ----

    function property_supply_conservation() external view returns (bool) {
        uint256 sum = token.balanceOf(address(this));
        for (uint256 i = 0; i < 3; i++) {
            sum += token.balanceOf(accounts[i]);
        }
        return token.totalSupply() == sum;
    }
}
