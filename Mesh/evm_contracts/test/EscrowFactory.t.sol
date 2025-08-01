// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/EscrowFactory.sol";
import "../src/EscrowSrc.sol";
import "../src/EscrowDst.sol";
import "../src/IFusionPlus.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing
contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract EscrowFactoryTest is Test {
    EscrowFactory public factory;
    EscrowSrc public escrowSrc;
    EscrowDst public escrowDst;
    MockToken public mockToken;
    
    address public maker = address(0x1);
    address public taker = address(0x2);
    address public other = address(0x3);
    address public accessTokenHolder = address(0x4);
    
    bytes32 public secret = bytes32("mysecret");
    bytes32 public orderHash;
    uint256 public amount = 1000 * 10**18; // 1000 tokens
    uint256 public safetyDeposit = 0.1 ether;
    
    IFusionPlus.Immutables public immutables;
    IFusionPlus.Timelocks public timelocks;
    
    event EscrowSrcCreated(
        bytes32 indexed orderHash,
        address indexed maker,
        address indexed taker,
        uint256 amount,
        bytes32 hashlock,
        uint256 safetyDeposit
    );
    
    event EscrowDstCreated(
        bytes32 indexed orderHash,
        address indexed maker,
        address indexed taker,
        uint256 amount,
        bytes32 hashlock,
        uint256 safetyDeposit
    );

    function setUp() public {
        // Deploy mock token
        mockToken = new MockToken("Mock Token", "MTK");
        
        // Deploy escrow contracts
        escrowSrc = new EscrowSrc();
        escrowDst = new EscrowDst();
        
        // Deploy factory
        factory = new EscrowFactory(address(escrowSrc), address(escrowDst));
        
        // Setup test addresses
        vm.deal(maker, 20 ether);
        vm.deal(taker, 20 ether);
        vm.deal(other, 20 ether);
        vm.deal(accessTokenHolder, 20 ether);
        
        // Give tokens to maker and taker
        mockToken.mint(maker, 10000 * 10**18);
        mockToken.mint(taker, 10000 * 10**18);
        
        // Add access token holders
        escrowSrc.addAccessTokenHolder(accessTokenHolder);
        escrowDst.addAccessTokenHolder(accessTokenHolder);
        
        // Setup timelocks
        timelocks = IFusionPlus.Timelocks({
            srcWithdrawal: block.timestamp + 1 hours,
            srcPublicWithdrawal: block.timestamp + 2 hours,
            srcCancellation: block.timestamp + 3 hours,
            dstWithdrawal: block.timestamp + 4 hours,
            dstPublicWithdrawal: block.timestamp + 5 hours,
            dstCancellation: block.timestamp + 6 hours
        });
        
        // Setup immutables
        immutables = IFusionPlus.Immutables({
            maker: maker,
            taker: taker,
            amount: amount,
            safetyDeposit: safetyDeposit,
            hashlock: keccak256(abi.encodePacked(secret)),
            timelocks: timelocks,
            token: address(mockToken),
            chainId: 1
        });
        
        // Generate order hash
        orderHash = keccak256(abi.encodePacked(
            maker,
            taker,
            amount,
            safetyDeposit,
            immutables.hashlock,
            timelocks.srcWithdrawal,
            timelocks.srcPublicWithdrawal,
            timelocks.srcCancellation,
            address(mockToken),
            1
        ));
    }

    function test_CreateEscrowSrc() public {
        vm.startPrank(maker);
        
        // Approve tokens
        mockToken.approve(address(escrowSrc), amount);
        
        // Create escrow through factory
        factory.createEscrowSrc{value: safetyDeposit}(orderHash, immutables);
        
        // Verify escrow was created
        IFusionPlus.EscrowStatus memory status = escrowSrc.escrowStatuses(orderHash);
        assertEq(status.isFilled, false);
        assertEq(status.isCancelled, false);
        assertEq(status.deployedAt, block.timestamp);
        assertEq(status.filledAt, 0);
        assertEq(status.cancelledAt, 0);
        
        // Verify immutables were stored
        IFusionPlus.Immutables memory stored = escrowSrc.escrowImmutables(orderHash);
        assertEq(stored.maker, maker);
        assertEq(stored.taker, taker);
        assertEq(stored.amount, amount);
        assertEq(stored.safetyDeposit, safetyDeposit);
        assertEq(stored.hashlock, immutables.hashlock);
        assertEq(stored.token, address(mockToken));
        assertEq(stored.chainId, 1);
        
        vm.stopPrank();
    }

    function test_CreateEscrowDst() public {
        vm.startPrank(taker);
        
        // Approve tokens
        mockToken.approve(address(escrowDst), amount);
        
        // Create escrow through factory
        factory.createEscrowDst{value: safetyDeposit}(orderHash, immutables);
        
        // Verify escrow was created
        IFusionPlus.EscrowStatus memory status = escrowDst.escrowStatuses(orderHash);
        assertEq(status.isFilled, false);
        assertEq(status.isCancelled, false);
        assertEq(status.deployedAt, block.timestamp);
        assertEq(status.filledAt, 0);
        assertEq(status.cancelledAt, 0);
        
        // Verify immutables were stored
        IFusionPlus.Immutables memory stored = escrowDst.escrowImmutables(orderHash);
        assertEq(stored.maker, maker);
        assertEq(stored.taker, taker);
        assertEq(stored.amount, amount);
        assertEq(stored.safetyDeposit, safetyDeposit);
        assertEq(stored.hashlock, immutables.hashlock);
        assertEq(stored.token, address(mockToken));
        assertEq(stored.chainId, 1);
        
        vm.stopPrank();
    }

    function test_CreateEscrowSrc_RevertIfAlreadyExists() public {
        vm.startPrank(maker);
        
        // Approve tokens
        mockToken.approve(address(escrowSrc), amount);
        
        // Create escrow first time
        factory.createEscrowSrc{value: safetyDeposit}(orderHash, immutables);
        
        // Try to create again - should revert
        vm.expectRevert("Escrow already exists");
        factory.createEscrowSrc{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
    }

    function test_CreateEscrowDst_RevertIfAlreadyExists() public {
        vm.startPrank(taker);
        
        // Approve tokens
        mockToken.approve(address(escrowDst), amount);
        
        // Create escrow first time
        factory.createEscrowDst{value: safetyDeposit}(orderHash, immutables);
        
        // Try to create again - should revert
        vm.expectRevert("Escrow already exists");
        factory.createEscrowDst{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
    }

    function test_CreateEscrowSrc_RevertIfInsufficientDeposit() public {
        vm.startPrank(maker);
        
        // Approve tokens
        mockToken.approve(address(escrowSrc), amount);
        
        // Try to create with insufficient deposit
        vm.expectRevert("Insufficient safety deposit");
        factory.createEscrowSrc{value: safetyDeposit - 0.01 ether}(orderHash, immutables);
        
        vm.stopPrank();
    }

    function test_CreateEscrowDst_RevertIfInsufficientDeposit() public {
        vm.startPrank(taker);
        
        // Approve tokens
        mockToken.approve(address(escrowDst), amount);
        
        // Try to create with insufficient deposit
        vm.expectRevert("Insufficient safety deposit");
        factory.createEscrowDst{value: safetyDeposit - 0.01 ether}(orderHash, immutables);
        
        vm.stopPrank();
    }

    function test_FillEscrowSrc() public {
        vm.startPrank(maker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowSrc), amount);
        factory.createEscrowSrc{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Fill escrow as taker
        vm.prank(taker);
        factory.fillEscrowSrc(orderHash, secret);
        
        // Verify escrow was filled
        IFusionPlus.EscrowStatus memory status = escrowSrc.escrowStatuses(orderHash);
        assertEq(status.isFilled, true);
        assertEq(status.filledAt, block.timestamp);
        assertEq(status.isCancelled, false);
        assertEq(status.cancelledAt, 0);
    }

    function test_FillEscrowDst() public {
        vm.startPrank(taker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowDst), amount);
        factory.createEscrowDst{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Fill escrow as maker
        vm.prank(maker);
        factory.fillEscrowDst(orderHash, secret);
        
        // Verify escrow was filled
        IFusionPlus.EscrowStatus memory status = escrowDst.escrowStatuses(orderHash);
        assertEq(status.isFilled, true);
        assertEq(status.filledAt, block.timestamp);
        assertEq(status.isCancelled, false);
        assertEq(status.cancelledAt, 0);
    }

    function test_FillEscrowSrc_RevertIfNotTaker() public {
        vm.startPrank(maker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowSrc), amount);
        factory.createEscrowSrc{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Try to fill as non-taker
        vm.prank(other);
        vm.expectRevert("Invalid caller");
        factory.fillEscrowSrc(orderHash, secret);
    }

    function test_FillEscrowDst_RevertIfNotMaker() public {
        vm.startPrank(taker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowDst), amount);
        factory.createEscrowDst{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Try to fill as non-maker
        vm.prank(other);
        vm.expectRevert("Invalid caller");
        factory.fillEscrowDst(orderHash, secret);
    }

    function test_FillEscrowSrc_RevertIfInvalidSecret() public {
        vm.startPrank(maker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowSrc), amount);
        factory.createEscrowSrc{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Try to fill with invalid secret
        vm.prank(taker);
        vm.expectRevert("Invalid secret");
        factory.fillEscrowSrc(orderHash, bytes32("wrongsecret"));
    }

    function test_FillEscrowDst_RevertIfInvalidSecret() public {
        vm.startPrank(taker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowDst), amount);
        factory.createEscrowDst{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Try to fill with invalid secret
        vm.prank(maker);
        vm.expectRevert("Invalid secret");
        factory.fillEscrowDst(orderHash, bytes32("wrongsecret"));
    }

    function test_CancelEscrowSrc() public {
        vm.startPrank(maker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowSrc), amount);
        factory.createEscrowSrc{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Fast forward past cancellation time
        vm.warp(block.timestamp + 4 hours);
        
        // Cancel escrow
        vm.prank(maker);
        factory.cancelEscrowSrc(orderHash);
        
        // Verify escrow was cancelled
        IFusionPlus.EscrowStatus memory status = escrowSrc.escrowStatuses(orderHash);
        assertEq(status.isCancelled, true);
        assertEq(status.cancelledAt, block.timestamp);
        assertEq(status.isFilled, false);
        assertEq(status.filledAt, 0);
    }

    function test_CancelEscrowDst() public {
        vm.startPrank(taker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowDst), amount);
        factory.createEscrowDst{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Fast forward past cancellation time
        vm.warp(block.timestamp + 7 hours);
        
        // Cancel escrow
        vm.prank(taker);
        factory.cancelEscrowDst(orderHash);
        
        // Verify escrow was cancelled
        IFusionPlus.EscrowStatus memory status = escrowDst.escrowStatuses(orderHash);
        assertEq(status.isCancelled, true);
        assertEq(status.cancelledAt, block.timestamp);
        assertEq(status.isFilled, false);
        assertEq(status.filledAt, 0);
    }

    function test_WithdrawEscrowSrc() public {
        vm.startPrank(maker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowSrc), amount);
        factory.createEscrowSrc{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Fast forward past withdrawal time
        vm.warp(block.timestamp + 2 hours);
        
        // Withdraw escrow
        vm.prank(maker);
        factory.withdrawEscrowSrc(orderHash);
        
        // Verify tokens were returned to maker
        assertEq(mockToken.balanceOf(maker), 10000 * 10**18); // Original balance
    }

    function test_WithdrawEscrowDst() public {
        vm.startPrank(taker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowDst), amount);
        factory.createEscrowDst{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Fast forward past withdrawal time
        vm.warp(block.timestamp + 5 hours);
        
        // Withdraw escrow
        vm.prank(taker);
        factory.withdrawEscrowDst(orderHash);
        
        // Verify tokens were returned to taker
        assertEq(mockToken.balanceOf(taker), 10000 * 10**18); // Original balance
    }

    function test_PublicWithdrawEscrowSrc() public {
        vm.startPrank(maker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowSrc), amount);
        factory.createEscrowSrc{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Fast forward past public withdrawal time
        vm.warp(block.timestamp + 3 hours);
        
        // Public withdraw escrow
        vm.prank(other);
        factory.publicWithdrawEscrowSrc(orderHash);
        
        // Verify tokens were returned to maker
        assertEq(mockToken.balanceOf(maker), 10000 * 10**18); // Original balance
    }

    function test_PublicWithdrawEscrowDst() public {
        vm.startPrank(taker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowDst), amount);
        factory.createEscrowDst{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Fast forward past public withdrawal time
        vm.warp(block.timestamp + 6 hours);
        
        // Public withdraw escrow
        vm.prank(other);
        factory.publicWithdrawEscrowDst(orderHash);
        
        // Verify tokens were returned to taker
        assertEq(mockToken.balanceOf(taker), 10000 * 10**18); // Original balance
    }

    function test_GetEscrowSrcStatus() public {
        vm.startPrank(maker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowSrc), amount);
        factory.createEscrowSrc{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Get status
        IFusionPlus.EscrowStatus memory status = factory.getEscrowSrcStatus(orderHash);
        assertEq(status.isFilled, false);
        assertEq(status.isCancelled, false);
        assertEq(status.deployedAt, block.timestamp);
        assertEq(status.filledAt, 0);
        assertEq(status.cancelledAt, 0);
    }

    function test_GetEscrowDstStatus() public {
        vm.startPrank(taker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowDst), amount);
        factory.createEscrowDst{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Get status
        IFusionPlus.EscrowStatus memory status = factory.getEscrowDstStatus(orderHash);
        assertEq(status.isFilled, false);
        assertEq(status.isCancelled, false);
        assertEq(status.deployedAt, block.timestamp);
        assertEq(status.filledAt, 0);
        assertEq(status.cancelledAt, 0);
    }

    function test_GetEscrowSrcImmutables() public {
        vm.startPrank(maker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowSrc), amount);
        factory.createEscrowSrc{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Get immutables
        IFusionPlus.Immutables memory stored = factory.getEscrowSrcImmutables(orderHash);
        assertEq(stored.maker, maker);
        assertEq(stored.taker, taker);
        assertEq(stored.amount, amount);
        assertEq(stored.safetyDeposit, safetyDeposit);
        assertEq(stored.hashlock, immutables.hashlock);
        assertEq(stored.token, address(mockToken));
        assertEq(stored.chainId, 1);
    }

    function test_GetEscrowDstImmutables() public {
        vm.startPrank(taker);
        
        // Approve tokens and create escrow
        mockToken.approve(address(escrowDst), amount);
        factory.createEscrowDst{value: safetyDeposit}(orderHash, immutables);
        
        vm.stopPrank();
        
        // Get immutables
        IFusionPlus.Immutables memory stored = factory.getEscrowDstImmutables(orderHash);
        assertEq(stored.maker, maker);
        assertEq(stored.taker, taker);
        assertEq(stored.amount, amount);
        assertEq(stored.safetyDeposit, safetyDeposit);
        assertEq(stored.hashlock, immutables.hashlock);
        assertEq(stored.token, address(mockToken));
        assertEq(stored.chainId, 1);
    }
} 