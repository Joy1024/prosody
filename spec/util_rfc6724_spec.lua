
local rfc6724 = require "util.rfc6724";
local new_ip = require"util.ip".new_ip;

describe("util.rfc6724", function()
	describe("#source()", function()
		it("should work", function()
			assert.are.equal(rfc6724.source(new_ip("2001:db8:1::1", "IPv6"),
					{new_ip("2001:db8:3::1", "IPv6"), new_ip("fe80::1", "IPv6")}).addr,
				"2001:db8:3::1",
				"prefer appropriate scope");
			assert.are.equal(rfc6724.source(new_ip("ff05::1", "IPv6"),
					{new_ip("2001:db8:3::1", "IPv6"), new_ip("fe80::1", "IPv6")}).addr,
				"2001:db8:3::1",
				"prefer appropriate scope");
			assert.are.equal(rfc6724.source(new_ip("2001:db8:1::1", "IPv6"),
					{new_ip("2001:db8:1::1", "IPv6"), new_ip("2001:db8:2::1", "IPv6")}).addr,
				"2001:db8:1::1",
				"prefer same address"); -- "2001:db8:1::1" should be marked "deprecated" here, we don't handle that right now
			assert.are.equal(rfc6724.source(new_ip("fe80::1", "IPv6"),
					{new_ip("fe80::2", "IPv6"), new_ip("2001:db8:1::1", "IPv6")}).addr,
				"fe80::2",
				"prefer appropriate scope"); -- "fe80::2" should be marked "deprecated" here, we don't handle that right now
			assert.are.equal(rfc6724.source(new_ip("2001:db8:1::1", "IPv6"),
					{new_ip("2001:db8:1::2", "IPv6"), new_ip("2001:db8:3::2", "IPv6")}).addr,
				"2001:db8:1::2",
				"longest matching prefix");
		--[[ "2001:db8:1::2" should be a care-of address and "2001:db8:3::2" a home address, we can't handle this and would fail
			assert.are.equal(rfc6724.source(new_ip("2001:db8:1::1", "IPv6"),
					{new_ip("2001:db8:1::2", "IPv6"), new_ip("2001:db8:3::2", "IPv6")}).addr,
				"2001:db8:3::2",
				"prefer home address");
		]]
			assert.are.equal(rfc6724.source(new_ip("2002:c633:6401::1", "IPv6"),
					{new_ip("2002:c633:6401::d5e3:7953:13eb:22e8", "IPv6"), new_ip("2001:db8:1::2", "IPv6")}).addr,
				"2002:c633:6401::d5e3:7953:13eb:22e8",
				"prefer matching label"); -- "2002:c633:6401::d5e3:7953:13eb:22e8" should be marked "temporary" here, we don't handle that right now
			assert.are.equal(rfc6724.source(new_ip("2001:db8:1::d5e3:0:0:1", "IPv6"),
					{new_ip("2001:db8:1::2", "IPv6"), new_ip("2001:db8:1::d5e3:7953:13eb:22e8", "IPv6")}).addr,
				"2001:db8:1::d5e3:7953:13eb:22e8",
				"prefer temporary address") -- "2001:db8:1::2" should be marked "public" and "2001:db8:1::d5e3:7953:13eb:22e8" should be marked "temporary" here, we don't handle that right now
		end);
	end);
	describe("#destination()", function()
		it("should work", function()
			local order;
			order = rfc6724.destination({new_ip("2001:db8:1::1", "IPv6"), new_ip("198.51.100.121", "IPv4")},
				{new_ip("2001:db8:1::2", "IPv6"), new_ip("fe80::1", "IPv6"), new_ip("169.254.13.78", "IPv4")})
			assert.are.equal(order[1].addr, "2001:db8:1::1", "prefer matching scope");
			assert.are.equal(order[2].addr, "198.51.100.121", "prefer matching scope");

			order = rfc6724.destination({new_ip("2001:db8:1::1", "IPv6"), new_ip("198.51.100.121", "IPv4")},
				{new_ip("fe80::1", "IPv6"), new_ip("198.51.100.117", "IPv4")})
			assert.are.equal(order[1].addr, "198.51.100.121", "prefer matching scope");
			assert.are.equal(order[2].addr, "2001:db8:1::1", "prefer matching scope");

			order = rfc6724.destination({new_ip("2001:db8:1::1", "IPv6"), new_ip("10.1.2.3", "IPv4")},
				{new_ip("2001:db8:1::2", "IPv6"), new_ip("fe80::1", "IPv6"), new_ip("10.1.2.4", "IPv4")})
			assert.are.equal(order[1].addr, "2001:db8:1::1", "prefer higher precedence");
			assert.are.equal(order[2].addr, "10.1.2.3", "prefer higher precedence");

			order = rfc6724.destination({new_ip("2001:db8:1::1", "IPv6"), new_ip("fe80::1", "IPv6")},
				{new_ip("2001:db8:1::2", "IPv6"), new_ip("fe80::2", "IPv6")})
			assert.are.equal(order[1].addr, "fe80::1", "prefer smaller scope");
			assert.are.equal(order[2].addr, "2001:db8:1::1", "prefer smaller scope");

		--[[ "2001:db8:1::2" and "fe80::2" should be marked "care-of address", while "2001:db8:3::1" should be marked "home address", we can't currently handle this and would fail the test
			order = rfc6724.destination({new_ip("2001:db8:1::1", "IPv6"), new_ip("fe80::1", "IPv6")},
				{new_ip("2001:db8:1::2", "IPv6"), new_ip("2001:db8:3::1", "IPv6"), new_ip("fe80::2", "IPv6")})
			assert.are.equal(order[1].addr, "2001:db8:1::1", "prefer home address");
			assert.are.equal(order[2].addr, "fe80::1", "prefer home address");
		]]

		--[[ "fe80::2" should be marked "deprecated", we can't currently handle this and would fail the test
			order = rfc6724.destination({new_ip("2001:db8:1::1", "IPv6"), new_ip("fe80::1", "IPv6")},
				{new_ip("2001:db8:1::2", "IPv6"), new_ip("fe80::2", "IPv6")})
			assert.are.equal(order[1].addr, "2001:db8:1::1", "avoid deprecated addresses");
			assert.are.equal(order[2].addr, "fe80::1", "avoid deprecated addresses");
		]]

			order = rfc6724.destination({new_ip("2001:db8:1::1", "IPv6"), new_ip("2001:db8:3ffe::1", "IPv6")},
				{new_ip("2001:db8:1::2", "IPv6"), new_ip("2001:db8:3f44::2", "IPv6"), new_ip("fe80::2", "IPv6")})
			assert.are.equal(order[1].addr, "2001:db8:1::1", "longest matching prefix");
			assert.are.equal(order[2].addr, "2001:db8:3ffe::1", "longest matching prefix");

			order = rfc6724.destination({new_ip("2002:c633:6401::1", "IPv6"), new_ip("2001:db8:1::1", "IPv6")},
				{new_ip("2002:c633:6401::2", "IPv6"), new_ip("fe80::2", "IPv6")})
			assert.are.equal(order[1].addr, "2002:c633:6401::1", "prefer matching label");
			assert.are.equal(order[2].addr, "2001:db8:1::1", "prefer matching label");

			order = rfc6724.destination({new_ip("2002:c633:6401::1", "IPv6"), new_ip("2001:db8:1::1", "IPv6")},
				{new_ip("2002:c633:6401::2", "IPv6"), new_ip("2001:db8:1::2", "IPv6"), new_ip("fe80::2", "IPv6")})
			assert.are.equal(order[1].addr, "2001:db8:1::1", "prefer higher precedence");
			assert.are.equal(order[2].addr, "2002:c633:6401::1", "prefer higher precedence");
		end);
	end);
end);
