# @title Serenus Coin Insurance contract
# @notice The Insurance contract receives ETH funds when a contract is taken over
# @notice It pays out when anyone calls it with the address of an issuer that is
# @notice under-collateralised (under 100% collateral) and it will attempt to return it to above 100%
# @notice Source code found at https://github.com/serenuscoin
# @notice Use at your own risk
# @dev Compiled with Vyper 0.1.0b8

contract ERC20Serenus:
    def minter_addresses(_issuer: address) -> bool: constant

# @dev Contract interface for Governor
contract Governor:
    def nonce() -> int128: constant
    def erc20_serenus() -> address: constant
    def oracle() -> address: constant
    def owner() -> address: constant
    def factory() -> address: constant
    def insurance() -> address: constant
    def insurance_payoff() -> uint256: constant
    
# @dev Contract interface for Issuer
contract Issuer:
    def num_issued() -> uint256: constant
    def poolInsuranceDeposit(): modifying
    
# @dev Contract interface for the Oracle
contract Oracle:
    def read() -> uint256: constant

receivePool: event({amount: uint256(wei), from: indexed(address)})
sendPool: event({amount: uint256(wei), from: indexed(address)})

erc20_serenus: ERC20Serenus
governor: Governor
oracle: Oracle

owner: public(address)

nonce: public(int128)
insurance_payoff: public(uint256)                           # in bips
issuer: public(address)

@public
def __init__():
    self.owner = msg.sender
    self.governor = ZERO_ADDRESS

# @notice Receive funds into the insurance pool
@public
@payable
def __default__():
    log.receivePool(msg.value, msg.sender)
    
# @notice This is called directly after contract creation
# @notice It may be needed if the governor changes later
@public
def setGovernorAddress(_address: address):
    assert msg.sender == self.governor.owner() or self.governor == ZERO_ADDRESS
    self.governor = _address

# @notice Anyone can force the issuer to read new Governor contract values (if any)
@public
def readGovernor():
    self.nonce = self.governor.nonce()
    self.erc20_serenus = self.governor.erc20_serenus()
    self.oracle = self.governor.oracle()
    self.insurance = self.governor.insurance()
    self.insurance_payoff = self.governor.insurance_payoff()

@public
def changeOwner(_address: address):
    assert msg.sender == self.owner
    self.owner = _address

# @notice send eth to contracts with more liabilities than assets
@public
def send_collateral(_issuer_address: address):
    assert self.erc20_serenus.minter_addresses(_issuer_address) == True

    _eth_usd: uint256 = self.oracle.read()
    _balance: uint256(wei) = _issuer_address.balance
    self.issuer = _issuer_address
    _supply: uint256 = self.issuer.num_issued()

    assert _supply > 0
    assert (_balance * _eth_usd / 100) * 10000 / _supply < 10000

    _amount: uint256(wei) = ((_supply + _supply * self.insurance_payoff / 10000) - (_balance * _eth_usd / 100)) / (_eth_usd / 100)

    Issuer(_issuer_address).poolInsuranceDeposit(value=_amount)
    log.sendPool(_amount, _issuer_address)
