package ir.legion.w2ray.engine

import java.security.SecureRandom

/**
 * Makes QUIC (UDP/443) fail fast instead of silently.
 *
 * hev-socks5-tunnel cannot send ICMP "port unreachable", so a dropped datagram looks like a black hole and a
 * browser waits seconds before it falls back to TCP. A QUIC client does react at once to a Version Negotiation
 * packet (RFC 9000 section 17.2.1) that lists no version it supports: the attempt ends with an error and the
 * browser uses HTTPS over TCP. That is what this class answers to a client Initial.
 */
object QuicBlocker {
    private val random = SecureRandom()

    /** A reserved "greasing" version (RFC 9000 section 15.1): no real client supports it. */
    private const val GREASE_VERSION = 0x1a2a3a4a

    /** Initial datagrams must be at least 1200 bytes (RFC 9000 section 14.1); smaller ones get no answer. */
    private const val MIN_INITIAL = 1200

    /** The Version Negotiation packet for a client's QUIC long-header [datagram], or null when none should be sent. */
    fun versionNegotiation(datagram: ByteArray): ByteArray? {
        if (datagram.size < MIN_INITIAL) return null
        val first = datagram[0].toInt() and 255
        if (first and 0x80 == 0) return null // short header: not an Initial
        val version = ((datagram[1].toInt() and 255) shl 24) or ((datagram[2].toInt() and 255) shl 16) or
            ((datagram[3].toInt() and 255) shl 8) or (datagram[4].toInt() and 255)
        if (version == 0) return null // never answer a Version Negotiation packet
        var i = 5
        val dcidLen = datagram[i++].toInt() and 255
        if (dcidLen > 255 || i + dcidLen >= datagram.size) return null
        val dcid = datagram.copyOfRange(i, i + dcidLen)
        i += dcidLen
        val scidLen = datagram[i++].toInt() and 255
        if (i + scidLen > datagram.size) return null
        val scid = datagram.copyOfRange(i, i + scidLen)

        val out = ByteArray(1 + 4 + 1 + scid.size + 1 + dcid.size + 4)
        var o = 0
        out[o++] = (0x80 or (random.nextInt() and 0x7f)).toByte()
        o += 4 // version 0
        // The ids are swapped: the client's source id is our destination id.
        out[o++] = scid.size.toByte()
        System.arraycopy(scid, 0, out, o, scid.size); o += scid.size
        out[o++] = dcid.size.toByte()
        System.arraycopy(dcid, 0, out, o, dcid.size); o += dcid.size
        out[o++] = (GREASE_VERSION ushr 24).toByte()
        out[o++] = (GREASE_VERSION ushr 16).toByte()
        out[o++] = (GREASE_VERSION ushr 8).toByte()
        out[o] = GREASE_VERSION.toByte()
        return out
    }
}
