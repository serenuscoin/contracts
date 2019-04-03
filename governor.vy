# @title Serenus Coin Governor contract
# @notice Sets global governance parameters
# @notice No Issuer contract can mint/burn unless up-to-date
# @notice Source code found at https://github.com/serenuscoin
# @notice Use at your own risk
# @dev Compiled with Vyper 0.1.0b8

owner: public(address)

nonce: public(int128)
issuer_fees: public(uint256)
minimum_collateral_ratio: public(uint256)
liquidity_multiplier: public(uint256)
erc20_serenus: public(address)
oracle: public(address)
factory: public(address)
insurance: public(address)
insurance_fee: public(uint256)
insurance_payoff: public(uint256)

@public
def __init__():
    self.owner = msg.sender
    self.nonce = 5
    self.issuer_fees = 20                                   # in bips
    self.minimum_collateral_ratio = 12000                   # in bips; 120 percent
    self.liquidity_multiplier = 1 * 10**18                  # 1 ether (in wei) per cent of ETH/USD price
    self.erc20_serenus = ZERO_ADDRESS
    self.oracle = ZERO_ADDRESS
    self.factory = ZERO_ADDRESS
    self.insurance = ZERO_ADDRESS
    self.insurance_fee = 500                                # in bips; 5 percent
    self.insurance_payoff = 1000                            # in bips; 10 percent
    
@public
def changeOwner(_address: address):
    assert msg.sender == self.owner
    self.owner = _address

@public
def liquidate():
    assert msg.sender == self.owner
    selfdestruct(self.owner)
    
@public
def setParameters(_issuer_fees: uint256, _minimum_collateral_ratio: uint256,
                  _liquidity_multiplier: uint256, _erc20_serenus: address, _oracle: address,
                  _factory: address, _insurance: address, _insurance_fee: uint256, _insurance_payoff: uint256):
    assert msg.sender == self.owner

    self.nonce += 1
    self.issuer_fees = _issuer_fees                           # in bips
    self.minimum_collateral_ratio = _minimum_collateral_ratio # in bips
    self.liquidity_multiplier = _liquidity_multiplier         # wei per cent of ETH/USD price
    self.erc20_serenus = _erc20_serenus
    self.oracle = _oracle
    self.factory = _factory
    self.insurance = _insurance
    self.insurance_fee = _insurance_fee                       # in bips
    self.insurance_payoff = _insurance_payoff                 # in bips
