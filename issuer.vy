# @title Serenus Coin Issuer contract
# @notice Anyone can create an Issuer instance using a template
# @notice The contract can become leveraged long ETH/USD
# @notice A target collateral ratio is set on creation and is modifiable
# @notice Source code found at https://github.com/serenuscoin
# @notice Use at your own risk
# @dev Compiled with Vyper 0.1.0b8

# @dev Contract interface for ERC20Serenus
contract ERC20Serenus:
    def burn(_address: address, _amount: uint256(wei)): modifying
    def mint(_address: address, _amount: uint256(wei)): modifying
    def removeMinterAddress(): modifying

# @dev Contract interface for Governor
contract Governor:
    def nonce() -> int128: constant
    def issuer_fees() -> uint256: constant
    def minimum_collateral_ratio() -> uint256: constant
    def liquidity_multiplier() -> uint256: constant
    def erc20_serenus() -> address: constant
    def oracle() -> address: constant
    def owner() -> address: constant
    def factory() -> address: constant
    def insurance() -> address: constant
    def insurance_fee() -> uint256: constant
    
# @dev Contract interface for Issuer
contract Issuer:
    def receiveBalances(_owner: address, _num_issued: uint256(wei)): modifying
    
# @dev Contract interface for the Oracle
contract Oracle:
    def read() -> uint256: constant

# @dev Contract interface for the Factory
contract Factory:
    def createIssuer(_owner: address, _target_collateral_ratio: uint256) -> address: modifying

# @dev Contract interface for Insurance
contract Insurance:
    def requestFunds(): constant
    
boughtTokens: event({_from: indexed(address), _to: indexed(address), _value: uint256(wei)})
soldTokens: event({_from: indexed(address), _to: indexed(address), _value: uint256(wei)})
liquidateContract: event({_selfaddress: indexed(address)})
takeoverOwner: event({_owner: indexed(address)})
markedForTakeover: event({_sender: indexed(address)})
    
erc20_serenus: ERC20Serenus
governor: Governor
oracle: Oracle
factory: Factory

ETHUSDprice: public(uint256)                                # in cents

issuer_id: public(int128)
owner: public(address)
target_collateral_ratio: public(uint256)                    # in bips

nonce: public(int128)
issuer_fees: public(uint256)                                # in bips
minimum_collateral_ratio: public(uint256)                   # in bips
liquidity_multiplier: public(uint256)
insurance_fee: public(uint256)                              # in bips
insurance: public(address)

marked_on_block: public(uint256)

# @dev An internal erc-20 tracking variable
num_issued: public(uint256(wei))

# @notice Setup is and can only be called once on creation
# @params A unique id
# @params The owner of this Issuer
# @params Governor contract address
# @params A target collateral ratio for this Issuer
@public
def setup(_id: int128, _owner: address, _governor: address, _target_collateral_ratio: uint256):
    assert self.owner == ZERO_ADDRESS

    self.owner = _owner
    self.issuer_id = _id
    self.governor = _governor
    self.target_collateral_ratio = _target_collateral_ratio
    
    self.nonce = self.governor.nonce()
    self.issuer_fees = self.governor.issuer_fees()
    self.minimum_collateral_ratio = self.governor.minimum_collateral_ratio()
    self.liquidity_multiplier = self.governor.liquidity_multiplier()
    self.erc20_serenus = self.governor.erc20_serenus()
    self.oracle = self.governor.oracle()
    self.factory = self.governor.factory()
    self.insurance = self.governor.insurance()
    self.insurance_fee = self.governor.insurance_fee()
    
    assert self.target_collateral_ratio >= self.minimum_collateral_ratio

    self.num_issued = 0

@public
def changeOwner(_address: address):
    assert msg.sender == self.owner
    self.owner = _address

@public
def setGovernorAddress(_address: address):
    assert msg.sender == self.governor.owner()
    self.governor = _address

# @notice Anyone can force the issuer to read new Governor contract values (if any)
@public
def readGovernor():
    self.nonce = self.governor.nonce()
    self.issuer_fees = self.governor.issuer_fees()
    self.minimum_collateral_ratio = self.governor.minimum_collateral_ratio()
    self.liquidity_multiplier = self.governor.liquidity_multiplier()
    self.erc20_serenus = self.governor.erc20_serenus()
    self.oracle = self.governor.oracle()
    self.factory = self.governor.factory()
    self.insurance = self.governor.insurance()
    self.insurance_fee = self.governor.insurance_fee()

# @notice The owner can reset a desirable collateral ratio
@public
def setTargetCollateralRatio(_new_ratio: uint256):
    assert msg.sender == self.owner
    self.target_collateral_ratio = _new_ratio

# @notice Insurance pool can fund an issuer
@public
@payable
def poolInsuranceDeposit():
    assert msg.sender == self.insurance
    
# @notice The owner must send in some ether and may need to top up later
@public
@payable
def issuerDeposit():
    assert msg.sender == self.owner

# @notice Withdrawal can only occur if there is sufficient collateral to cover it
@public
def issuerWithdrawal(_amount: uint256(wei)):
    assert msg.sender == self.owner

    self.ETHUSDprice = self.oracle.read()
    
    assert _amount <= self.balance
    if self.num_issued != 0:
        assert ((self.balance - _amount) * self.ETHUSDprice / 100) * 10000 / self.num_issued >= self.target_collateral_ratio

    send(self.owner, _amount)

# @notice The owner can close the Issuer contract if all issued serenus has been paid back
@public
def issuerLiquidate():
    assert msg.sender == self.owner
    assert self.num_issued == 0
    self.erc20_serenus.removeMinterAddress()
    log.liquidateContract(self)
    selfdestruct(self.owner)

# @notice Users may buy tokens from this Issuer contract
# @dev Read a new price from the Oracle
# @dev Calculate how many tokens to mint and fees to the Issuer
# @dev Adjust prices for exchange liquidity estimate
# @dev Check that this Issuer is able to mint that many tokens
@public
@payable
def buyTokens():
    self.ETHUSDprice = self.oracle.read()
    
    _issuer_fees: uint256(wei) = (msg.value * self.issuer_fees) / 10000
    
    _value: uint256(wei) = msg.value - _issuer_fees

    _adjustedPrice: uint256 = self.ETHUSDprice - as_unitless_number(_value) / self.liquidity_multiplier
    
    _issuing: uint256(wei) = (_value * _adjustedPrice) / 100
    assert _issuing > 0

    assert (self.balance * _adjustedPrice / 100) * 10000 / (self.num_issued + _issuing) >= self.target_collateral_ratio
    
    # sending tokens
    self.num_issued += _issuing
    self.erc20_serenus.mint(msg.sender, _issuing)
    log.boughtTokens(ZERO_ADDRESS, msg.sender, _issuing)

# @notice Users may sell tokens to receive ether back
# @params Amount of tokens being sold by the user
# @dev Make sure the issuer has minted at least this many tokens
# @dev Adjust prices for exchange liquidity estimate
@public
def sellTokens(_value: uint256(wei)):
    assert _value <= self.num_issued

    self.ETHUSDprice = self.oracle.read()
    
    _adjustedPrice: uint256 = self.ETHUSDprice + as_unitless_number(_value) / self.ETHUSDprice / self.liquidity_multiplier
    
    _ether: uint256(wei) = (_value * 100) / _adjustedPrice

    # adjust tokens, send ether
    self.erc20_serenus.burn(msg.sender, _value)
    self.num_issued -= _value
    send(msg.sender, _ether)
    log.soldTokens(msg.sender, ZERO_ADDRESS, _value)

# @notice Replace issuer if insufficient collateral is available
# @dev Read current price and check collateral against minimum collateral ratio
# @dev At least one block must have passed before the last mark
# @dev This helps prevent atomically spiking Uniswap prices to falsely takeover a contract
# @dev Replacer must have paid in sufficient collateral to "win" the remainder from the old owner
@public
@payable
def replaceIssuer():
    assert self.num_issued != 0
    assert block.number - self.marked_on_block > 1 and self.marked_on_block != 0

    self.ETHUSDprice = self.oracle.read()

    # check that issuer has less than the minimum collateral
    assert ((self.balance - msg.value) * self.ETHUSDprice / 100) * 10000 / self.num_issued < self.minimum_collateral_ratio

    # send an insurance pool addition
    send(self.insurance, (self.balance - msg.value) * self.insurance_fee / 10000)

    # then check whether there is still enough to collateralise the contract
    assert (self.balance * self.ETHUSDprice / 100) * 10000 / self.num_issued >= self.minimum_collateral_ratio
    
    self.owner = msg.sender
    log.takeoverOwner(self.owner)
    
# @notice Before trying to replace the issuer's owner mark the contract
# @dev use the block number to track when the mark happened
@public
def markForTakeover() -> bool:
    self.ETHUSDprice = self.oracle.read()
    if (self.balance * self.ETHUSDprice / 100) * 10000 / self.num_issued < self.minimum_collateral_ratio:
        self.marked_on_block = block.number
        log.markedForTakeover(msg.sender)
        return True
    else:
        self.marked_on_block = 0
        return False

# @notice Migrate state onto new issuer contract
# @dev No plans for active usage; ownership is preserved
@public
def sendBalances():
    assert msg.sender == self.owner or msg.sender == self.governor.owner()
    self.ETHUSDprice = self.oracle.read()
    assert (self.balance * self.ETHUSDprice / 100) * 10000 / self.num_issued >= self.minimum_collateral_ratio

    _new_issuer: address = self.factory.createIssuer(self.owner, self.target_collateral_ratio)
    self.erc20_serenus.removeMinterAddress()
    Issuer(_new_issuer).receiveBalances(self.owner, self.num_issued, value=self.balance)
    log.liquidateContract(self)
    selfdestruct(self.owner)

# @notice Migrate state onto new issuer contract
# @dev No plans for active usage; ownership is preserved
@payable
@public
def receiveBalances(_owner: address, _num_issued: uint256(wei)):
    assert _owner == self.owner
    self.num_issued += _num_issued

