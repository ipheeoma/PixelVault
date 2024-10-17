;; PixelVault NFT Marketplace Smart Contract

;; Define constants
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-listing-not-found (err u102))

;; Define NFT asset
(define-non-fungible-token pixelvault uint)

;; Define data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var next-token-id uint u1)

;; Define data maps
(define-map tokens
  { token-id: uint }
  { owner: principal, uri: (string-utf8 256) }
)

(define-map listings
  { token-id: uint }
  { price: uint, seller: principal }
)

;; Private function to check contract ownership
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; Transfer contract ownership
(define-public (transfer-contract-ownership (new-owner principal))
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    (ok (var-set contract-owner new-owner))
  )
)

;; Get current contract owner
(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)

;; Mint new NFT
(define-public (mint (uri (string-utf8 256)))
  (let
    (
      (token-id (var-get next-token-id))
    )
    (try! (nft-mint? pixelvault token-id tx-sender))
    (map-set tokens
      { token-id: token-id }
      { owner: tx-sender, uri: uri }
    )
    (var-set next-token-id (+ token-id u1))
    (ok token-id)
  )
)

;; List NFT for sale
(define-public (list-nft (token-id uint) (price uint))
  (let
    (
      (token-owner (unwrap! (nft-get-owner? pixelvault token-id) (err u103)))
    )
    (asserts! (is-eq tx-sender token-owner) err-not-token-owner)
    (map-set listings
      { token-id: token-id }
      { price: price, seller: tx-sender }
    )
    (ok true)
  )
)

;; Cancel NFT listing
(define-public (cancel-listing (token-id uint))
  (let
    (
      (listing (unwrap! (map-get? listings { token-id: token-id }) err-listing-not-found))
    )
    (asserts! (is-eq tx-sender (get seller listing)) err-not-token-owner)
    (map-delete listings { token-id: token-id })
    (ok true)
  )
)

;; Buy NFT
(define-public (buy-nft (token-id uint))
  (let
    (
      (listing (unwrap! (map-get? listings { token-id: token-id }) err-listing-not-found))
      (price (get price listing))
      (seller (get seller listing))
    )
    (try! (stx-transfer? price tx-sender seller))
    (try! (nft-transfer? pixelvault token-id seller tx-sender))
    (map-delete listings { token-id: token-id })
    (map-set tokens
      { token-id: token-id }
      { owner: tx-sender, uri: (get uri (unwrap! (map-get? tokens { token-id: token-id }) (err u104))) }
    )
    (ok true)
  )
)

;; Get token URI
(define-read-only (get-token-uri (token-id uint))
  (ok (get uri (unwrap! (map-get? tokens { token-id: token-id }) (err u105))))
)

;; Get token owner
(define-read-only (get-token-owner (token-id uint))
  (ok (get owner (unwrap! (map-get? tokens { token-id: token-id }) (err u106))))
)

;; Get listing details
(define-read-only (get-listing (token-id uint))
  (ok (unwrap! (map-get? listings { token-id: token-id }) err-listing-not-found))
)