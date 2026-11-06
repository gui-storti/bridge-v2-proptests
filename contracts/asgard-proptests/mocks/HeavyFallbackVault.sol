// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.2;

/**
 * @dev Mock etherVault cujo fallback consome mais de 2300 gas (SSTORE), fazendo o
 *      `.send()` do TokenSale retornar `false`.
 */
contract HeavyFallbackVault {
    uint256 public counter;

    receive() external payable {
        counter = counter + 1; // SSTORE (5000+ gas) > 2300 gas do .send()
    }
}
