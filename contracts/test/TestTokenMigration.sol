pragma solidity 0.8.6;

import './helpers/TestBaseWorkflowV2.sol';
import './helpers/TestBaseWorkflowV1.sol';
import {JBV3Token} from '../JBV3Token.sol';
import 'forge-std/Test.sol';

contract TestTokenMigration is TestBaseWorkflowV2, TestBaseWorkflowV1 {
  address _projectOwner = address(0xf00ba6);
  uint256 _v3ProjectId;
  uint256 _v2ProjectId;
  uint256 _v1ProjectId = 3;

  FundingCycle _currentV1FundingCycle;
  JBFundingCycle _currentV2FundingCycle;
  JBFundingCycle _currentV3FundingCycle;


  // v3 instances
  JBTokenStore _v3JbTokenStore;
  JBV3Token _v3Token;
  JBDirectory _v3jJbDirectory;
  JBController v3controller;
  JBFundingCycleStore _jbFundingCycleStore;

  // v2 instances
  JBController v2controller;
  JBProjectMetadata _projectMetadata;
  JBFundingCycleData _data;
  JBFundAccessConstraints[] _fundAccessConstraint;
  JBGroupedSplits[] _groupedSplits;
  JBFundingCycleMetadata _metadata;
  IJBPaymentTerminal[] _terminals; // Default empty
  JBSplitsStore _jbSplitsStore;

  function setUp() public override(TestBaseWorkflowV2, TestBaseWorkflowV1) {
    TestBaseWorkflowV2.setUp();

    v2controller = jbController();

    _jbSplitsStore = jbSplitsStore();

    _projectMetadata = JBProjectMetadata({content: 'myIPFSHash', domain: 1});

    _data = JBFundingCycleData({
      duration: 14,
      weight: 1000 * 10**18,
      discountRate: 450000000,
      ballot: IJBFundingCycleBallot(address(0))
    });

    _metadata = JBFundingCycleMetadata({
      global: JBGlobalFundingCycleMetadata({allowSetTerminals: false, allowSetController: false}),
      reservedRate: 5000, //50%
      redemptionRate: 5000, //50%
      ballotRedemptionRate: 0,
      pausePay: false,
      pauseDistributions: false,
      pauseRedeem: false,
      pauseBurn: false,
      allowMinting: false,
      allowChangeToken: false,
      allowTerminalMigration: false,
      allowControllerMigration: false,
      holdFees: false,
      useTotalOverflowForRedemptions: false,
      useDataSourceForPay: false,
      useDataSourceForRedeem: false,
      dataSource: address(0)
    });

    _terminals.push(jbETHPaymentTerminal());

    _fundAccessConstraint.push(JBFundAccessConstraints({
        terminal: jbETHPaymentTerminal(),
        token: jbLibraries().ETHToken(),
        distributionLimit: 0,
        overflowAllowance: 0,
        distributionLimitCurrency: jbLibraries().ETH(),
        overflowAllowanceCurrency: jbLibraries().ETH()
    }));

    evm.prank(_projectOwner);
    _v2ProjectId = v2controller.launchProjectFor(
      _projectOwner,
      _projectMetadata,
      _data,
      _metadata,
      block.timestamp,
      _groupedSplits,
      _fundAccessConstraint,
      _terminals,
      ''
    );

    evm.prank(_projectOwner);
    v2controller.issueTokenFor(_v2ProjectId, 'v2 token', 'v2 token');

    // mimicing a v3 project launch since there was dependency issue with importing both v2 & v3 contract togethet since the almost every contract is the same
    _setupV3ProjectToMigrateTokensTo();
  }

  function _setupV3ProjectToMigrateTokensTo () internal {
    JBProjects _jbProjects = new JBProjects(jbOperatorStore());

    address preDeterministicJBDirectory = addressFrom(address(this), 15);

    // JBFundingCycleStore
    _jbFundingCycleStore = new JBFundingCycleStore(IJBDirectory(preDeterministicJBDirectory));

    // JBDirectory
    _v3jJbDirectory = new JBDirectory(jbOperatorStore(), _jbProjects, _jbFundingCycleStore, multisig());

    // JBTokenStore
    _v3JbTokenStore = new JBTokenStore(jbOperatorStore(), _jbProjects, _v3jJbDirectory);

    // JBSplitsStore
    JBSplitsStore _newJbSplitsStore = new JBSplitsStore(jbOperatorStore(), _jbProjects, _v3jJbDirectory);

    // JBController
    v3controller = new JBController(
      jbOperatorStore(),
      _jbProjects,
      _v3jJbDirectory,
      _jbFundingCycleStore,
      _v3JbTokenStore,
      _newJbSplitsStore
    );

    evm.prank(multisig());
    _v3jJbDirectory.setIsAllowedToSetFirstController(address(v3controller), true);

    // JBETHPaymentTerminalStore
    JBSingleTokenPaymentTerminalStore _jbPaymentTerminalStore = new JBSingleTokenPaymentTerminalStore(
      _v3jJbDirectory,
      _jbFundingCycleStore,
      jbPrices()
    );

    // AccessJBLib
    AccessJBLib _accessJBLib = new AccessJBLib();

    // JBETHPaymentTerminal
    JBETHPaymentTerminal _jbETHPaymentTerminal = new JBETHPaymentTerminal(
      _accessJBLib.ETH(),
      jbOperatorStore(),
      _jbProjects,
      _v3jJbDirectory,
      _newJbSplitsStore,
      jbPrices(),
      _jbPaymentTerminalStore,
      multisig()
    );

   IJBPaymentTerminal[] memory _newProjectterminals = new IJBPaymentTerminal[](1);
    _newProjectterminals[0] = (_jbETHPaymentTerminal);

    _fundAccessConstraint.push(JBFundAccessConstraints({
        terminal: _jbETHPaymentTerminal,
        token: jbLibraries().ETHToken(),
        distributionLimit: 0,
        overflowAllowance: 0,
        distributionLimitCurrency: jbLibraries().ETH(),
        overflowAllowanceCurrency: jbLibraries().ETH()
    }));

   
    _metadata.allowMinting = true;

    // mimicing a v3 project launch since there was dependency issue with importing both v2 & v3 contract togethet since the almost every contract is the same
    evm.prank(_projectOwner);
    _v3ProjectId = v3controller.launchProjectFor(
      _projectOwner,
      _projectMetadata,
      _data,
      _metadata,
      block.timestamp,
      _groupedSplits,
      _fundAccessConstraint,
      _newProjectterminals,
      ''
    );

    assertEq(_jbProjects.ownerOf(_v3ProjectId), _projectOwner);

    TestBaseWorkflowV1.setUp();
    
    // deploying v3 token
    _v3Token = new JBV3Token('v3 token', 'v3 token', _v3ProjectId, ticketBooth(), jbTokenStore(), fundingCycles(), v2controller, v3controller, _v1ProjectId);

  }

  function test_Migration_When_User_Has_Claimed_And_Unclaimed_Balances() public {
    TerminalV1_1 _v1Terminal = terminal();
    JBETHPaymentTerminal _v2Terminal = jbETHPaymentTerminal();

    address _user = address(bytes20(keccak256('user')));

    // fund user
    evm.deal(_user, 4 ether);

    // pay project and getting unclaimed tickets
    evm.prank(_user);
    _v1Terminal.pay{value: 1 ether}(
      _v1ProjectId,
      _user,
      'Take my money',
       false
    );

    // pay project and getting claimed tickets
    evm.prank(_user);
    _v1Terminal.pay{value: 1 ether}(
      _v1ProjectId,
      _user,
      'Take my money',
       true
    );

    assertEq(_v1Terminal.balanceOf(_v1ProjectId), 2 ether);
    
    // pay project and getting unclaimed token balance for v2
    evm.prank(_user);
    _v2Terminal.pay{value: 1 ether}(
      _v2ProjectId,
      1 ether,
      address(0),
      /* _beneficiary */
      _user,
      /* _minReturnedTokens */
      0,
      /* _preferClaimedTokens */
      false,
      /* _memo */
      'Take my money!',
      /* _delegateMetadata */
      new bytes(0)
    );

    // pay project and getting claimed tokens sent for v2
    evm.prank(_user);
    _v2Terminal.pay{value: 1 ether}(
      _v2ProjectId,
      1 ether,
      address(0),
      /* _beneficiary */
      _user,
      /* _minReturnedTokens */
      0,
      /* _preferClaimedTokens */
      true,
      /* _memo */
      'Take my money!',
      /* _delegateMetadata */
      new bytes(0)
    );

    assertEq(jbPaymentTerminalStore().balanceOf(_v2Terminal, _v2ProjectId), 2 ether);

    // giving all necessary permissions
    IJBToken _token = jbTokenStore().tokenOf(_v2ProjectId);
    evm.prank(_user);
    _token.approve(_v2ProjectId, address(_v3Token), 1000000 ether);

    ITickets _v1Token = ticketBooth().ticketsOf(_v1ProjectId);
    evm.prank(_user);
    _v1Token.approve(address(_v3Token), 1000000 ether);

    uint256[] memory _transferPermissionIndexForV2 = new uint256[](1);
    _transferPermissionIndexForV2[0] = JBOperations.TRANSFER;

    evm.prank(_user);
    jbOperatorStore().setOperator(
      JBOperatorData(address(_v3Token), _v2ProjectId, _transferPermissionIndexForV2)
    );

    uint256[] memory _transferPermissionIndexForV1 = new uint256[](1);
    _transferPermissionIndexForV1[0] = Operations.Transfer;

    evm.prank(_user);
    operatorStore().setOperator(
      address(_v3Token), _v1ProjectId, _transferPermissionIndexForV1
    );
    {
    _currentV1FundingCycle = fundingCycles().currentOf(_v1ProjectId);
    _currentV2FundingCycle = jbFundingCycleStore().currentOf(_v2ProjectId);
    _currentV3FundingCycle = _jbFundingCycleStore.currentOf(_v2ProjectId);

    // v1 balances
    uint256 v1UnclaimedBalance = ticketBooth().stakedBalanceOf(_user, _v1ProjectId);
    uint256 v1ClaimedBalance = _v1Token.balanceOf(_user);
    uint256 expectedV1TokensMigrated = PRBMath.mulDiv(v1UnclaimedBalance + v1ClaimedBalance, _currentV3FundingCycle.weight, _currentV1FundingCycle.weight);

    // v2 balances
    uint256 unclaimedBalance = jbTokenStore().unclaimedBalanceOf(_user, _v2ProjectId);
    uint256 claimedBalance = _token.balanceOf(_user, _v2ProjectId);
    uint256 expectedV2TokensMigrated = PRBMath.mulDiv(unclaimedBalance + claimedBalance, _currentV3FundingCycle.weight, _currentV2FundingCycle.weight);

    evm.prank(_user);
    _v3Token.migrate();

    uint256 v3TokenBalance = _v3Token.balanceOf(_user, _v3ProjectId);
    assertEq(v3TokenBalance, expectedV2TokensMigrated + expectedV1TokensMigrated);
    }
  }

    function test_Migration_When_User_Has_No_Claimed_And_Unclaimed_Balances() public {
    address _user = address(bytes20(keccak256('user')));

    // fund user
    evm.deal(_user, 2 ether);

    IJBToken _token = jbTokenStore().tokenOf(_v2ProjectId);
    evm.prank(_user);
    _token.approve(_v3ProjectId, address(_v3Token), 1000000 ether);

    uint256[] memory _transferPermissionIndex = new uint256[](1);
    _transferPermissionIndex[0] = JBOperations.TRANSFER;

    evm.prank(_user);
    jbOperatorStore().setOperator(
      JBOperatorData(address(_v3Token), _v2ProjectId, _transferPermissionIndex)
    );

    evm.prank(_user);
    _v3Token.migrate();

    uint256 v3TokenBalance = _v3Token.balanceOf(_user, _v3ProjectId);
    assertEq(v3TokenBalance, 0);
  }
}