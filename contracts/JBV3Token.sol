// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

// TODO: Due to the contract names being thhe same in v2 & v3 repo mmixing the imports cause compilation issue in this context importing only either v2 or v3 tokens should be okay?
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol';
import '@jbx-protocol-v2/contracts/interfaces/IJBToken.sol';
import '@jbx-protocol-v2/contracts/interfaces/IJBController.sol';
import '@jbx-protocol-v2/contracts/interfaces/IJBDirectory.sol';
import '@jbx-protocol-v2/contracts/interfaces/IJBTokenStore.sol';
import '@jbx-protocol-v1/contracts/interfaces/ITicketBooth.sol';

/** 
  @notice
  An ERC-20 token that can be used by a project in the `JBTokenStore`.

  @dev
  Adheres to -
  IJBToken: Allows this contract to be used by projects in the JBTokenStore.

  @dev
  Inherits from -
  ERC20Votes: General token standard for fungible membership with snapshot capabilities sufficient to interact with standard governance contracts. 
  Ownable: Includes convenience functionality for checking a message sender's permissions before executing certain transactions.
*/
contract JBV3Token is ERC20Votes, Ownable, IJBToken {
  //*********************************************************************//
  // --------------------------- custom errors ------------------------- //
  //*********************************************************************//
  error BAD_PROJECT();
  error INSUFFICIENT_FUNDS();
  error UNEXPECTED_AMOUNT();

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
    The V3 Directory Instance. 
  */
  IJBDirectory public immutable v3Directory;

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

    return super.totalSupply() + 
    v1TicketBooth.totalSupplyOf(projectId) + 
    v2TokenStore.totalSupplyOf(projectId) -
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
    _account; // Prevents unused var compiler and natspec complaints.
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

  //*********************************************************************//
  // -------------------------- constructor ---------------------------- //
  //*********************************************************************//

  /** 
    @param _name The name of the token.
    @param _symbol The symbol that the token should be represented by.
    @param _projectId The ID of the project that this token should be exclusively used for. Send 0 to support any project.
    @param _v3Directory V3 Directory Instance.
    @param _v1TicketBooth V1 Token Booth Instance.
    @param _v2TokenStore V2 Token Store Instance.
  */
  constructor(
    string memory _name,
    string memory _symbol,
    uint256 _projectId,
    IJBDirectory _v3Directory,
    ITicketBooth _v1TicketBooth,
    IJBTokenStore _v2TokenStore
  ) ERC20(_name, _symbol) ERC20Permit(_name) {
    projectId = _projectId;
    v1TicketBooth = _v1TicketBooth;
    v2TokenStore = _v2TokenStore;
    v3Directory = _v3Directory;
  }

  //*********************************************************************//
  // ---------------------- external transactions ---------------------- //
  //*********************************************************************//

  /** 
    @notice
    Mints more of the token.

    @dev
    Only the owner of this contract cant mint more of it.

    @param _projectId The ID of the project to which the token belongs. This is ignored.
    @param _account The account to mint the tokens for.
    @param _amount The amount of tokens to mint, as a fixed point number with 18 decimals.
  */
  function mint(
    uint256 _projectId,
    address _account,
    uint256 _amount
  ) external override onlyOwner {
    // Can't mint for a wrong project.
    if (projectId != 0 && _projectId != projectId) revert BAD_PROJECT();

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
    // Can't burn for a wrong project.
    if (projectId != 0 && _projectId != projectId) revert BAD_PROJECT();

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
    // Can't approve for a wrong project.
    if (projectId != 0 && _projectId != projectId) revert BAD_PROJECT();

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
    // Can't transfer for a wrong project.
    if (projectId != 0 && _projectId != projectId) revert BAD_PROJECT();

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
    // Can't transfer for a wrong project.
    if (projectId != 0 && _projectId != projectId) revert BAD_PROJECT();

    transferFrom(_from, _to, _amount);
  }

  function transferOwnership(uint256 _projectId, address _newOwner) external pure override {
    _projectId;
    _newOwner;
    // there are dependency issues with both v2 & v3 imports due to same name of contract/interfaces
    revert("not available");
  }

  /** 
    @notice
    Migrate v1 & v2 tokens to v3.
  */
  function migrate() external {
    uint256 _fundsToMigrateFromV1;
    uint256 _fundsToMigrateFromV2;
    if (address(v1TicketBooth) != address(0)) {
      // Get a reference to the v1 projects ERC20 tokens.
      ITickets _v1Token = v1TicketBooth.ticketsOf(projectId);
      _fundsToMigrateFromV1 = _migrateV1Tokens(_v1Token);
    }

    if (address(v2TokenStore) != address(0)) {
      // Get a reference to the v2 project's ERC20 tokens.
      IJBToken _v2Token = v2TokenStore.tokenOf(projectId);
      _fundsToMigrateFromV2 = _migrateV2Tokens(_v2Token);
    }

    uint256 _tokensToMint = _fundsToMigrateFromV1 + _fundsToMigrateFromV2;
    // mint tokens directly
    _mint(msg.sender, _tokensToMint);
  }

  /** 
    @notice
    Migrate v1 tokens to v3.
    @param _v1Token The v1 token instance.
  */
  function _migrateV1Tokens(ITickets _v1Token) internal returns(uint256) {     
    // Get a reference to the migrator's unclaimed balance.
    uint256 _tokensToMintFromUnclaimedBalance = v1TicketBooth.stakedBalanceOf(msg.sender, projectId);

    // Get a reference to the migrator's ERC20 balance.
    uint256 _tokensToMintFromERC20s = _v1Token == ITickets(address(0)) ? 0 : _v1Token.balanceOf(msg.sender);
    
    // total v3 tokens to mint
    uint256 v3TokensToMint = _tokensToMintFromERC20s + _tokensToMintFromUnclaimedBalance;

    if (v3TokensToMint == 0)
      revert INSUFFICIENT_FUNDS();

    // Transfer v1 ERC20 tokens to this contract from the msg sender if needed.
    if (_tokensToMintFromERC20s != 0)
      IERC20(_v1Token).transferFrom(msg.sender, address(this), _tokensToMintFromERC20s);

    // Transfer v1 unclaimed tokens to this contract from the msg sender if needed.
    if (_tokensToMintFromUnclaimedBalance != 0)
      v1TicketBooth.transfer(
        msg.sender,
        projectId,
        _tokensToMintFromUnclaimedBalance,
        address(this)
      );
    
    return v3TokensToMint;
  }

  /** 
    @notice
    Migrate v2 tokens to v3.
    @param _v2Token The v2 token instance.
  */
  function _migrateV2Tokens(IJBToken _v2Token) internal returns(uint256) {
    // Get a reference to the migrator's unclaimed balance.
    uint256 _tokensToMintFromUnclaimedBalance = v2TokenStore.unclaimedBalanceOf(msg.sender, projectId);

    // Get a reference to the migrator's ERC20 balance.
    uint256 _tokensToMintFromERC20s = _v2Token == IJBToken(address(0)) ? 0 : _v2Token.balanceOf(msg.sender, projectId);
    
    // total v3 tokens to mint
    uint256 v3TokensToMint = _tokensToMintFromERC20s + _tokensToMintFromUnclaimedBalance;

    if (v3TokensToMint == 0)
      revert INSUFFICIENT_FUNDS();

    // Transfer v2 ERC20 tokens to this contract from the msg sender if needed.
    if (_tokensToMintFromERC20s != 0)
      IJBToken(_v2Token).transferFrom(projectId, msg.sender, address(this), _tokensToMintFromERC20s);

    // Transfer v2 unclaimed tokens to this contract from the msg sender if needed.
    if (_tokensToMintFromUnclaimedBalance != 0)
      v2TokenStore.transferFrom(
        msg.sender,
        projectId,
        address(this),
        _tokensToMintFromUnclaimedBalance
      );
    
    return v3TokensToMint;
  }


}