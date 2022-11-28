// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import '@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol';
import '@jbx-protocol-v2/contracts/interfaces/IJBController.sol';
import '@jbx-protocol-v2/contracts/interfaces/IJBToken.sol';
import '@jbx-protocol-v2/contracts/interfaces/IJBTokenStore.sol';
import '@jbx-protocol-v1/contracts/interfaces/ITicketBooth.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

/** 
  @notice
  An ERC-20 token that can be used by a project in the `JBTokenStore` & also this takes care of the migration of the v1 & v2 project tokens for v3.

  @dev
  Adheres to -
  IJBToken: Allows this contract to be used by projects in the JBTokenStore.

  @dev
  Inherits from -
  ERC20Votes: General token standard for fungible membership with snapshot capabilities sufficient to interact with standard governance contracts. 
  Ownable: Includes convenience functionality for checking a message sender's permissions before executing certain transactions.
*/
contract JBV3Token is ERC20Permit, Ownable, IJBToken {
  //*********************************************************************//
  // --------------------- public stored properties -------------------- //
  //*********************************************************************//

  /** 
    @notice
    The ID of the project that this token should be exclusively used for. Send 0 to support any project. 
  */
  uint256 public immutable projectId;

  /** 
    @notice
    The V1 Token Booth Instance. 
  */
  ITicketBooth public immutable v1TicketBooth;

  /** 
    @notice
    The V2 Token Store Instance. 
  */
  IJBTokenStore public immutable v2TokenStore;

  /** 
    @notice
    Storing the id's to migrate from for the v3 project ID. 
  */
  mapping(uint256 => MigrationInfo) public migrationOf;

  /** 
    @notice
    v2ProjectId to migrate from. 
    v1ProjectId to migrate from. 
  */
  struct MigrationInfo {
    uint128 v2ProjectId;
    uint128 v1ProjectId;
  }

  //*********************************************************************//
  // ------------------------- external views -------------------------- //
  //*********************************************************************//

  /** 
    @notice
    The total supply of this ERC20.

    @param _projectId the ID of the project to which the token belongs. This is ignored.

    @return The total supply of this ERC20, as a fixed point number.
  */
  function totalSupply(uint256 _projectId) external view override returns (uint256) {
    _projectId; // Prevents unused var compiler and natspec complaints.

    (uint128 v2ProjectId, uint128 v1ProjectId) = getMigrationInfo(projectId);

    return super.totalSupply() + 
    v1TicketBooth.totalSupplyOf(v1ProjectId) + 
    v2TokenStore.totalSupplyOf(v2ProjectId) -
    v1TicketBooth.balanceOf(address(this), projectId) -
    v2TokenStore.balanceOf(address(this), projectId);
  }

  /** 
    @notice
    The total supply of this ERC20.

    @return The total supply of this ERC20, as a fixed point number.
  */
  function totalSupply() public view override returns (uint256) {
    (uint128 v2ProjectId, uint128 v1ProjectId) = getMigrationInfo(projectId);

    return super.totalSupply() + 
    v1TicketBooth.totalSupplyOf(v1ProjectId) + 
    v2TokenStore.totalSupplyOf(v2ProjectId) -
    v1TicketBooth.balanceOf(address(this), projectId) -
    v2TokenStore.balanceOf(address(this), projectId);
  }

  /** 
    @notice
    An account's balance of this ERC20.

    @param _account The account to get a balance of.
    @param _projectId is the ID of the project to which the token belongs. This is ignored.

    @return The balance of the `_account` of this ERC20, as a fixed point number with 18 decimals.
  */
  function balanceOf(address _account, uint256 _projectId)
    external
    view
    override
    returns (uint256)
  {
    _projectId; // Prevents unused var compiler and natspec complaints.

    return super.balanceOf(_account);
  }

  //*********************************************************************//
  // -------------------------- public views --------------------------- //
  //*********************************************************************//

  /** 
    @notice
    The number of decimals included in the fixed point accounting of this token.

    @return The number of decimals.
  */
  function decimals() public view override(ERC20, IJBToken) returns (uint8) {
    return super.decimals();
  }

  /** 
    @notice
    The token id's to migrate from.

    @return v1 & v2 project id's.
  */
  function getMigrationInfo(uint256 _projectId) public view returns(uint128, uint128) {
    MigrationInfo memory _migrationInfo = migrationOf[_projectId];
    return (_migrationInfo.v2ProjectId, _migrationInfo.v1ProjectId);
  }

  //*********************************************************************//
  // -------------------------- constructor ---------------------------- //
  //*********************************************************************//

  /** 
    @param _name The name of the token.
    @param _symbol The symbol that the token should be represented by.
    @param _projectId The v3 ID of the project that this token should be exclusively used for.
    @param _v1TicketBooth V1 Token Booth Instance.
    @param _v2TokenStore V2 Token Store Instance.
    @param _v2ProjectId V2 Project Id.
    @param _v1ProjectId V1 Project Id.
  */
  constructor(
    string memory _name,
    string memory _symbol,
    uint256 _projectId,
    ITicketBooth _v1TicketBooth,
    IJBTokenStore _v2TokenStore,
    uint128 _v2ProjectId,
    uint128 _v1ProjectId
  ) ERC20(_name, _symbol) ERC20Permit(_name) {
    projectId = _projectId;
    v1TicketBooth = _v1TicketBooth;
    v2TokenStore = _v2TokenStore;
    migrationOf[_projectId] = MigrationInfo({ v2ProjectId: _v2ProjectId, v1ProjectId: _v1ProjectId });
  }

  //*********************************************************************//
  // ---------------------- external transactions ---------------------- //
  //*********************************************************************//

  /** 
    @notice
    Mints more of the token.

    @dev
    Only the owner of this contract can mint more of it.

    @param _projectId The ID of the project to which the token belongs. This is ignored.
    @param _account The account to mint the tokens for.
    @param _amount The amount of tokens to mint, as a fixed point number with 18 decimals.
  */
  function mint(
    uint256 _projectId,
    address _account,
    uint256 _amount
  ) external override onlyOwner {
    return _mint(_account, _amount);
  }

  /** 
    @notice
    Burn some outstanding tokens.

    @dev
    Only the owner of this contract cant burn some of its supply.

    @param _projectId The ID of the project to which the token belongs. This is ignored.
    @param _account The account to burn tokens from.
    @param _amount The amount of tokens to burn, as a fixed point number with 18 decimals.
  */
  function burn(
    uint256 _projectId,
    address _account,
    uint256 _amount
  ) external override onlyOwner {
    return _burn(_account, _amount);
  }

  /** 
    @notice
    Approves an account to spend tokens on the `msg.sender`s behalf.

    @param _projectId the ID of the project to which the token belongs. This is ignored.
    @param _spender The address that will be spending tokens on the `msg.sender`s behalf.
    @param _amount The amount the `_spender` is allowed to spend.
  */
  function approve(
    uint256 _projectId,
    address _spender,
    uint256 _amount
  ) external override {
    approve(_spender, _amount);
  }

  /** 
    @notice
    Transfer tokens to an account.
    
    @param _projectId The ID of the project to which the token belongs. This is ignored.
    @param _to The destination address.
    @param _amount The amount of the transfer, as a fixed point number with 18 decimals.
  */
  function transfer(
    uint256 _projectId,
    address _to,
    uint256 _amount
  ) external override {
    transfer(_to, _amount);
  }

  /** 
    @notice
    Transfer tokens between accounts.

    @param _projectId The ID of the project to which the token belongs. This is ignored.
    @param _from The originating address.
    @param _to The destination address.
    @param _amount The amount of the transfer, as a fixed point number with 18 decimals.
  */
  function transferFrom(
    uint256 _projectId,
    address _from,
    address _to,
    uint256 _amount
  ) external override {
    transferFrom(_from, _to, _amount);
  }

  function transferOwnership(uint256 _projectId, address _newOwner) external override {
    _projectId; // Prevents unused var compiler and natspec complaints.

    return super.transferOwnership(_newOwner);
  }

  /** 
    @notice
    Migrate v1 & v2 tokens to v3.
  */
  function migrate() external {
    uint256 _tokensToMigrateFromV1;
    uint256 _tokensToMigrateFromV2;

    // getting the v1 & v2 id's to migrate from
    (uint128 _v2ProjectId, uint128 _v1ProjectId) = getMigrationInfo(projectId);

    if (address(v1TicketBooth) != address(0))
      // fetching the no of v1 tokens to migrate
      _tokensToMigrateFromV1 = _migrateV1Tokens(_v1ProjectId);

    if (address(v2TokenStore) != address(0))
      // fetching the no of v2 tokens to migrate
      _tokensToMigrateFromV2 = _migrateV2Tokens(_v2ProjectId);

    uint256 _tokensToMint = _tokensToMigrateFromV1 + _tokensToMigrateFromV2;
    // mint tokens directly
    _mint(msg.sender, _tokensToMint);
  }

  /** 
    @notice
    Migrate v1 tokens to v3.
    @param _v1ProjectId v1 project id.

    @return amount of v2 tokens to be migrated
  */
  function _migrateV1Tokens(uint128 _v1ProjectId) internal returns(uint256) {  
    // local reference to the the project's v1 token instance   
    ITickets _v1Token = v1TicketBooth.ticketsOf(_v1ProjectId);

    // Get a reference to the migrator's unclaimed balance.
    uint256 _tokensToMintFromUnclaimedBalance = v1TicketBooth.stakedBalanceOf(msg.sender, _v1ProjectId);

    // Get a reference to the migrator's ERC20 balance.
    uint256 _tokensToMintFromERC20s = _v1Token == ITickets(address(0)) ? 0 : _v1Token.balanceOf(msg.sender);
    
    // total v3 tokens to mint
    uint256 v3TokensToMint = _tokensToMintFromERC20s + _tokensToMintFromUnclaimedBalance;

    if (v3TokensToMint == 0)
      return 0;

    // Transfer v1 ERC20 tokens to this contract from the msg sender if needed.
    if (_tokensToMintFromERC20s != 0)
      IERC20(_v1Token).transferFrom(msg.sender, address(this), _tokensToMintFromERC20s);

    // Transfer v1 unclaimed tokens to this contract from the msg sender if needed.
    if (_tokensToMintFromUnclaimedBalance != 0)
      v1TicketBooth.transfer(
        msg.sender,
        _v1ProjectId,
        _tokensToMintFromUnclaimedBalance,
        address(this)
      );
    
    return v3TokensToMint;
  }

  /** 
    @notice
    Migrate v2 tokens to v3.
    @param _v2ProjectId v2 project id.

    @return amount of v2 tokens to be migrated
  */
  function _migrateV2Tokens(uint128 _v2ProjectId) internal returns(uint256) {
    // local reference to the the project's v2 token instance   
    IJBToken _v2Token = v2TokenStore.tokenOf(_v2ProjectId);

    // Get a reference to the migrator's unclaimed balane.
    uint256 _tokensToMintFromUnclaimedBalance = v2TokenStore.unclaimedBalanceOf(msg.sender, _v2ProjectId);

    // Get a reference to the migrator's ERC20 balance.
    uint256 _tokensToMintFromERC20s = _v2Token == IJBToken(address(0)) ? 0 : _v2Token.balanceOf(msg.sender, _v2ProjectId);
    
    // total v3 tokens to mint
    uint256 v3TokensToMint = _tokensToMintFromERC20s + _tokensToMintFromUnclaimedBalance;

    if (v3TokensToMint == 0)
      return 0;

    // Transfer v2 ERC20 tokens to this contract from the msg sender if needed.
    if (_tokensToMintFromERC20s != 0)
      IJBToken(_v2Token).transferFrom(projectId, msg.sender, address(this), _tokensToMintFromERC20s);

    // Transfer v2 unclaimed tokens to this contract from the msg sender if needed.
    if (_tokensToMintFromUnclaimedBalance != 0)
      v2TokenStore.transferFrom(
        msg.sender,
        _v2ProjectId,
        address(this),
        _tokensToMintFromUnclaimedBalance
      );
    
    return v3TokensToMint;
  }
}