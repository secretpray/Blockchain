import { Controller } from "@hotwired/stimulus"
import { BrowserProvider, getAddress } from "ethers"

export default class extends Controller {
  static targets = ["address", "message", "signature", "status"]

  async connectAndSign() {
    this.statusTarget.textContent = ""

    if (!window.ethereum) {
      this.statusTarget.textContent = "No Ethereum provider found (install MetaMask)."
      return
    }

    const provider = new BrowserProvider(window.ethereum)
    const accounts = await provider.send("eth_requestAccounts", [])
    const rawAccount = accounts?.[0]

    if (!rawAccount) {
      this.statusTarget.textContent = "No account selected."
      return
    }

    // Normalize to EIP-55 checksummed format
    const account = getAddress(rawAccount)

    // 1) nonce из API (auto-provisions user if not exists)
    const resp = await fetch(`/api/v1/users/${account.toLowerCase()}`)
    const data = await resp.json().catch(() => null)

    if (!data?.eth_nonce) {
      this.statusTarget.textContent = "Failed to get nonce. Please try again."
      return
    }

    // 2) prepare SIWE message (EIP-4361)  
    // [oai_citation:10‡Ethereum Improvement Proposals]
    // (https://eips.ethereum.org/EIPS/eip-4361?utm_source=octa.com)
    // Use await provider.getNetwork() for chainId if needed
    const domain = window.location.host
    const uri = window.location.origin
    const issuedAt = new Date().toISOString()
    const expirationTime = new Date(Date.now() + 5 * 60 * 1000).toISOString()

    const message = `${domain} wants you to sign in with your Ethereum account:
${account}

Sign in to the app.

URI: ${uri}
Version: 1
Chain ID: 1
Nonce: ${data.eth_nonce}
Issued At: ${issuedAt}
Expiration Time: ${expirationTime}`

    // 3) sign message
    const signer = await provider.getSigner()
    const signature = await signer.signMessage(message)

    // 4) submit
    this.addressTarget.value = account
    this.messageTarget.value = message
    this.signatureTarget.value = signature

    this.element.querySelector("form").requestSubmit()
  }
}