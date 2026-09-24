// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {StablecoinPadraoTether} from "../contracts/StablecoinPadraoTether.sol";

/// @notice Testes cobrindo todas as mecânicas do padrão Tether USDT
contract StablecoinPadraoTetherTest is Test {
    StablecoinPadraoTether token;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address hacker = makeAddr("hacker");

    uint256 constant CENTO = 100 * 10 ** 6; // 100 tokens, 6 decimais

    function setUp() public {
        // deploy com supply inicial 0 (como o Tether real em sua origem)
        token = new StablecoinPadraoTether(0, "Synthetic Dollar", "SYNUSD", 6);
    }

    // ---------------- metadados ----------------
    function test_Metadados() public view {
        assertEq(token.name(), "Synthetic Dollar");
        assertEq(token.symbol(), "SYNUSD");
        assertEq(token.decimals(), 6);
        assertEq(token.totalSupply(), 0);
    }

    // ---------------- emissão / resgate ----------------
    function test_Issue_AdicionaSaldoAoOwner() public {
        token.issue(CENTO);
        assertEq(token.totalSupply(), CENTO);
        assertEq(token.balanceOf(address(this)), CENTO);
    }

    function test_Redeem_Quantidade() public {
        token.issue(CENTO);
        token.redeem(30 * 10 ** 6);
        assertEq(token.totalSupply(), 70 * 10 ** 6);
    }

    function test_RevertSe_Issue_PorNaoOwner() public {
        vm.prank(alice);
        vm.expectRevert(bytes("Stablecoin: somente owner"));
        token.issue(CENTO);
    }

    // ---------------- transferência ----------------
    function test_Transfer_Simples() public {
        token.issue(CENTO);
        assertTrue(token.transfer(alice, CENTO));
        assertEq(token.balanceOf(alice), CENTO);
    }

    function test_Transfer_ComTaxa() public {
        token.issue(CENTO);
        // 0,10% por transferência (10 bps), teto 10 tokens (< 50, limite do padrão Tether)
        token.setParams(10, 10);

        token.transfer(alice, CENTO);

        // taxa = 100 * 10 / 10000 = 0,1 token -> vai ao owner
        uint256 taxa = CENTO * 10 / 10000;
        assertEq(token.balanceOf(alice), CENTO - taxa);
        assertEq(token.balanceOf(address(this)), taxa);
    }

    function test_RevertSe_Transfer_ComContratoPausado() public {
        token.issue(CENTO);
        token.pause();
        vm.expectRevert(bytes("Stablecoin: contrato pausado"));
        token.transfer(alice, CENTO);
    }

    // ---------------- blacklist ----------------
    function test_Blacklist_BloqueiaTransferencia() public {
        token.issue(CENTO);
        token.transfer(alice, CENTO);
        token.addBlackList(alice);

        vm.prank(alice);
        vm.expectRevert();
        token.transfer(bob, CENTO);
    }

    function test_DestroyBlackFunds_ConfiscaEQueima() public {
        token.issue(CENTO);
        token.transfer(hacker, CENTO);
        token.addBlackList(hacker);

        token.destroyBlackFunds(hacker);

        assertEq(token.balanceOf(hacker), 0);
        assertEq(token.totalSupply(), 0);
    }

    // ---------------- approve / transferFrom ----------------
    function test_TransferFrom_ConsumeAllowance() public {
        token.issue(CENTO);
        token.approve(alice, 50 * 10 ** 6);

        vm.prank(alice);
        assertTrue(token.transferFrom(address(this), bob, 50 * 10 ** 6));

        assertEq(token.balanceOf(bob), 50 * 10 ** 6);
        assertEq(token.allowance(address(this), alice), 0);
    }

    // ---------------- posse em 2 passos ----------------
    function test_AcceptOwnership() public {
        token.transferOwnership(alice);
        assertEq(token.getOwner(), address(this)); // ainda não trocou

        vm.prank(alice);
        token.acceptOwnership();

        assertEq(token.getOwner(), alice);
    }

    function test_RevertSe_AcceptOwnership_PorNaoAutorizado() public {
        token.transferOwnership(alice);
        vm.prank(bob);
        vm.expectRevert(bytes("Stablecoin: voce nao e o novo owner"));
        token.acceptOwnership();
    }

    // ---------------- setParams limites ----------------
    function test_RevertSe_SetParams_AcimaDoLimite() public {
        vm.expectRevert(bytes("Stablecoin: basis points acima do maximo (20)"));
        token.setParams(25, 10); // > 20 bps
    }

    // regressao do bug uint8 (10**decimals em solc <0.8 faz overflow silencioso):
    // em 0.6.6 com decimals=6, setParams(10,10) gravava maximumFee=640 em vez de 10_000_000
    function test_SetParams_MaxFee_CalculadoCorretamente() public {
        token.setParams(10, 10);
        assertEq(token.maximumFee(), 10 * 10 ** 6);
        assertEq(token.basisPointsRate(), 10);
    }
}
