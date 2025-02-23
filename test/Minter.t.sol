// 1:1 with Hardhat test
pragma solidity 0.8.13;

import './BaseTest.sol';

contract MinterTest is BaseTest {
    VotingEscrow escrow;
    GaugeFactory gaugeFactory;
    BribeFactory bribeFactory;
    Voter voter;
    RewardsDistributor distributor;
    Minter minter;

    function deployBase() public {
        vm.warp(block.timestamp + 1 weeks); // put some initial time in

        deployProxyAdmin();
        deployOwners();
        deployCoins();
        mintStables();
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e25;
        mintVara(owners, amounts);

        VeArtProxy artProxy = new VeArtProxy();

        VotingEscrow implEscrow = new VotingEscrow();
        proxy = new TransparentUpgradeableProxy(address(implEscrow), address(admin), abi.encodeWithSelector(VotingEscrow.initialize.selector, address(VARA), address(artProxy)));
        escrow = VotingEscrow(address(proxy));

        Pair implPair = new Pair();
        PairFactory implPairFactory = new PairFactory();
        proxy = new TransparentUpgradeableProxy(address(implPairFactory), address(admin), abi.encodeWithSelector(PairFactory.initialize.selector, address(implPair)));
        factory = PairFactory(address(proxy));

        Router implRouter = new Router();
        proxy = new TransparentUpgradeableProxy(address(implRouter), address(admin), abi.encodeWithSelector(Router.initialize.selector, address(factory), address(owner)));
        router = Router(payable(address(proxy)));
        
        Gauge implGauge = new Gauge();
        GaugeFactory implGaugeFactory = new GaugeFactory();
        proxy = new TransparentUpgradeableProxy(address(implGaugeFactory), address(admin), abi.encodeWithSelector(GaugeFactory.initialize.selector, address(implGauge)));
        gaugeFactory = GaugeFactory(address(proxy));

        InternalBribe implInternalBribe = new InternalBribe();
        ExternalBribe implExternalBribe = new ExternalBribe();
        BribeFactory implBribeFactory = new BribeFactory();
        proxy = new TransparentUpgradeableProxy(address(implBribeFactory), address(admin), abi.encodeWithSelector(BribeFactory.initialize.selector, address(implInternalBribe), address(implExternalBribe)));
        bribeFactory = BribeFactory(address(proxy));

        Voter implVoter = new Voter();
        proxy = new TransparentUpgradeableProxy(address(implVoter), address(admin), abi.encodeWithSelector(Voter.initialize.selector, address(escrow), address(factory), address(gaugeFactory), address(bribeFactory)));
        voter = Voter(address(proxy));

        address[] memory tokens = new address[](2);
        tokens[0] = address(FRAX);
        tokens[1] = address(VARA);
        voter.init(tokens, address(owner));
        VARA.approve(address(escrow), TOKEN_1);
        escrow.create_lock(TOKEN_1, 4 * 365 * 86400);

        RewardsDistributor implDistributor = new RewardsDistributor();
        proxy = new TransparentUpgradeableProxy(address(implDistributor), address(admin), abi.encodeWithSelector(RewardsDistributor.initialize.selector, address(escrow)));
        distributor = RewardsDistributor(address(proxy));

        escrow.setVoter(address(voter));

        Minter implMinter = new Minter();
        proxy = new TransparentUpgradeableProxy(address(implMinter), address(admin), abi.encodeWithSelector(Minter.initialize.selector, address(voter), address(escrow), address(distributor)));
        minter = Minter(address(proxy));

        distributor.setDepositor(address(minter));
        VARA.setMinter(address(minter));

        VARA.approve(address(router), TOKEN_1);
        FRAX.approve(address(router), TOKEN_1);
        router.addLiquidity(address(FRAX), address(VARA), false, TOKEN_1, TOKEN_1, 0, 0, address(owner), block.timestamp);

        address pair = router.pairFor(address(FRAX), address(VARA), false);

        VARA.approve(address(voter), 5 * TOKEN_100K);
        voter.createGauge(pair);
        vm.roll(block.number + 1); // fwd 1 block because escrow.balanceOfNFT() returns 0 in same block
        assertGt(escrow.balanceOfNFT(1), 995063075414519385);
        assertEq(VARA.balanceOf(address(escrow)), TOKEN_1);

        address[] memory pools = new address[](1);
        pools[0] = pair;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 5000;
        voter.vote(1, pools, weights);
    }

    function initializeVotingEscrow() public {
        deployBase();

        address[] memory claimants = new address[](1);
        claimants[0] = address(owner);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = TOKEN_1M;
        minter.init(claimants, amounts, 2e25);
        assertEq(escrow.ownerOf(2), address(owner));
        assertEq(escrow.ownerOf(3), address(0));
        vm.roll(block.number + 1);
        assertEq(VARA.balanceOf(address(minter)), 19 * TOKEN_1M);
    }

    function testMinterWeeklyDistribute() public {
        initializeVotingEscrow();

        minter.update_period();
        assertEq(minter.weekly(), 1_838_000 * 1e18); // 15M
        vm.warp(block.timestamp + 86400 * 7);
        vm.roll(block.number + 1);
        minter.update_period();
        assertEq(distributor.claimable(1), 0);
        assertLt(minter.weekly(), 1_838_000 * 1e18); // <15M for week shift
        vm.warp(block.timestamp + 86400 * 7);
        vm.roll(block.number + 1);
        minter.update_period();
        uint256 claimable = distributor.claimable(1);
        assertGt(claimable, 32141062267140);
        distributor.claim(1);
        assertEq(distributor.claimable(1), 0);

        uint256 weekly = minter.weekly();
        console2.log(weekly);
        console2.log(minter.calculate_growth(weekly));
        console2.log(VARA.totalSupply());
        console2.log(escrow.totalSupply());

        vm.warp(block.timestamp + 86400 * 7);
        vm.roll(block.number + 1);
        minter.update_period();
        console2.log(distributor.claimable(1));
        distributor.claim(1);
        vm.warp(block.timestamp + 86400 * 7);
        vm.roll(block.number + 1);
        minter.update_period();
        console2.log(distributor.claimable(1));
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;
        distributor.claim_many(tokenIds);
        vm.warp(block.timestamp + 86400 * 7);
        vm.roll(block.number + 1);
        minter.update_period();
        console2.log(distributor.claimable(1));
        distributor.claim(1);
        vm.warp(block.timestamp + 86400 * 7);
        vm.roll(block.number + 1);
        minter.update_period();
        console2.log(distributor.claimable(1));
        distributor.claim_many(tokenIds);
        vm.warp(block.timestamp + 86400 * 7);
        vm.roll(block.number + 1);
        minter.update_period();
        console2.log(distributor.claimable(1));
        distributor.claim(1);
    }
}
