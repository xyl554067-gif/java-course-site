package com.javacourse.service;

import org.apache.hc.client5.http.DnsResolver;

import java.net.InetAddress;
import java.net.UnknownHostException;

/** The HTTP client connects to the same addresses this resolver has checked. */
final class PublicModelDns implements DnsResolver {
    @Override
    public InetAddress[] resolve(String host) throws UnknownHostException {
        try {
            return requirePublic(InetAddress.getAllByName(host));
        } catch (IllegalArgumentException rejected) {
            throw new UnknownHostException("模型接口地址不能指向本机或内网服务");
        }
    }

    @Override
    public String resolveCanonicalHostname(String host) {
        return host;
    }

    static InetAddress[] requirePublic(InetAddress[] addresses) {
        for (InetAddress address : addresses) {
            if (!isPublic(address)) {
                throw new IllegalArgumentException("模型接口地址不能指向本机或内网服务");
            }
        }
        return addresses;
    }

    private static boolean isPublic(InetAddress address) {
        if (address.isAnyLocalAddress() || address.isLoopbackAddress() || address.isLinkLocalAddress()
                || address.isSiteLocalAddress() || address.isMulticastAddress()) return false;
        byte[] bytes = address.getAddress();
        int first = Byte.toUnsignedInt(bytes[0]);
        int second = Byte.toUnsignedInt(bytes[1]);
        if (bytes.length == 16) {
            // Only global unicast, excluding transition ranges that embed IPv4 targets.
            return (first & 0xe0) == 0x20 && !(first == 0x20 && (second == 2
                    || (second == 1 && bytes[2] == 0 && bytes[3] == 0)));
        }
        return first != 0 && first < 224 && !(first == 100 && (second & 0xc0) == 0x40)
                && !(first == 198 && (second == 18 || second == 19));
    }
}
