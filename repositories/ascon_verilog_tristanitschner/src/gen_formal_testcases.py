#!/bin/env python3

import sys

def parse_testcases(filename):
    with open(filename, "r") as f:
        lines = f.readlines()

    n_testcases = len(lines)//7

    tests = list()

    for i in range(n_testcases):
        testcase = lines[i*7:(i+1)*7]

        countspec = testcase[0].split()
        keyspec   = testcase[1].split()
        noncespec = testcase[2].split()
        ptspec    = testcase[3].split()
        adspec    = testcase[4].split()
        ctspec    = testcase[5].split()

        assert countspec[0] == "Count"
        assert countspec[1] == "="
        assert int(countspec[2]) == i+1

        assert keyspec[0] == "Key"
        assert keyspec[1] == "="
        key = bytes.fromhex(keyspec[2])

        assert noncespec[0] == "Nonce"
        assert noncespec[1] == "="
        nonce = bytes.fromhex(noncespec[2])

        assert ptspec[0] == "PT"
        assert ptspec[1] == "="
        if len(ptspec) == 3:
            plaintext = bytes.fromhex(ptspec[2])
        else:
            plaintext = b''

        assert adspec[0] == "AD"
        assert adspec[1] == "="
        if len(adspec) == 3:
            associated_data = bytes.fromhex(adspec[2])
        else:
            associated_data = b''

        assert ctspec[0] == "CT"
        assert ctspec[1] == "="
        ciphertext = bytes.fromhex(ctspec[2])

        tests.append({
            "key"             : key,
            "nonce"           : nonce,
            "plaintext"       : plaintext,
            "associated_data" : associated_data,
            "ciphertext"      : ciphertext,
        })
    return tests

def process_testcases(tests):
    # extract the tag and move it to its own value field
    for i, test in enumerate(tests):
        tag_len = 16
        ct_len = len(test["ciphertext"])
        test["tag"]        = test["ciphertext"][ct_len-tag_len:ct_len]
        test["ciphertext"] = test["ciphertext"][0:ct_len-tag_len]
        tests[i] = test

    # extract the words for ad, m, and c and generate the number of valid bytes in each word
    for i, test in enumerate(tests):
        ad_lastwordlen = len(test["associated_data"])     % 16
        ad_wordlen     = len(test["associated_data"])//16 + (1 if ad_lastwordlen else 0)
        ad_words       = list()
        ad_word_lens   = list()
        for j in range(ad_wordlen):
            ad_words.append(test["associated_data"][j*16:(j+1)*16])
            if j < ad_wordlen-1:
                ad_word_lens.append(16)
            else: # last
                ad_word_lens.append(16 if ad_lastwordlen == 0 else ad_lastwordlen)
                if ad_lastwordlen != 0:
                    ad_words[j] += b'\00'*(16-ad_lastwordlen)
        tests[i]["ad_words"]     = ad_words
        tests[i]["ad_word_lens"] = ad_word_lens

        p_lastwordlen = len(test["plaintext"])     % 16
        p_wordlen     = len(test["plaintext"])//16 + (1 if p_lastwordlen else 0)
        p_words       = list()
        p_word_lens   = list()
        for j in range(p_wordlen):
            p_words.append(test["plaintext"][j*16:(j+1)*16])
            if j < p_wordlen-1:
                p_word_lens.append(16)
            else: # last
                p_word_lens.append(16 if p_lastwordlen == 0 else p_lastwordlen)
                if p_lastwordlen != 0:
                    p_words[j] += b'\00'*(16-p_lastwordlen)
        tests[i]["p_words"]     = p_words
        tests[i]["p_word_lens"] = p_word_lens

        c_lastwordlen = len(test["ciphertext"]) % 16
        c_wordlen     = len(test["ciphertext"])//16 + (1 if c_lastwordlen else 0)
        c_words       = list()
        c_word_lens   = list()
        for j in range(c_wordlen):
            c_words.append(test["ciphertext"][j*16:(j+1)*16])
            if j < c_wordlen-1:
                c_word_lens.append(16)
            else: # last
                c_word_lens.append(16 if c_lastwordlen == 0 else c_lastwordlen)
                if c_lastwordlen != 0:
                    c_words[j] += b'\00'*(16-c_lastwordlen)
        tests[i]["c_words"]     = c_words
        tests[i]["c_word_lens"] = c_word_lens

def print_comment(string):
    print("// %s %s" % (sys.argv[0], string))

def gen_generate_header(i, s_enc_decn):
    template = """
generate if (formal_testcase == %d && formal_enc_decn == %d && formal_testcases_enabled != 0) begin : gen_formal_testcase%d_%s
"""
    print(template % (i, 1 if s_enc_decn else 0, i, "enc" if s_enc_decn else "dec"))

def gen_generate_footer():
    print("""
end endgenerate
""")

def gen_data_wires(test):
    template = "    wire [127:0] t_%s\t= transform(128'h%s);"
    print(template % ("key",   test["key"].hex()))
    print(template % ("nonce", test["nonce"].hex()))
    print(template % ("t", test["tag"].hex()))
    for i in range(len(test["ad_words"])):
        print(template % ("ad%d" % i, test["ad_words"][i].hex()))
    for i in range(len(test["p_words"])):
        print(template % ("p%d" % i, test["p_words"][i].hex()))
    for i in range(len(test["c_words"])):
        print(template % ("c%d" % i, test["c_words"][i].hex()))
    print(template % ("zero_word", "0"))

def gen_keep_wires(test):
    template = "    wire [15:0] t_%s_k\t= transform_keep(16'b%s);"
    print(template % ("key",   "1"*16))
    print(template % ("nonce", "1"*16))
    print(template % ("t",     "1"*16))
    for i in range(len(test["ad_word_lens"])):
        print(template % ("ad%d" % i, '1'*test["ad_word_lens"][i] + '0'*(16-test["ad_word_lens"][i])))
    for i in range(len(test["p_word_lens"])):
        print(template % ("p%d" % i, '1'*test["p_word_lens"][i] + '0'*(16-test["p_word_lens"][i])))
    for i in range(len(test["c_word_lens"])):
        print(template % ("c%d" % i, '1'*test["c_word_lens"][i] + '0'*(16-test["c_word_lens"][i])))

def gen_keyword_assumptions(test, enc_decn):
    template = """
    always @(posedge clk) begin
        if (s_valid && s_counter == 0) begin
            assume(s_enc_decn == 1'b%x);
            assume(s_nonce    == t_nonce);
            assume(s_ad       == 1'b%x);
            assume(s_p        == 1'b%x);
        end
    end
    """
    ad_present = len(test["ad_words"]) != 0
    p_present  = len(test["p_words"])  != 0
    print(template % (1 if enc_decn else 0, 1 if ad_present else 0, 1 if p_present else 0))

def gen_data_assumptions(test, enc_decn):
    template_start = """
    always @(posedge clk) begin
        if (s_valid) begin
            case (s_counter)
"""
    template = "                %d: assume(s_data == %s);"
    template_end = """
                default: ;
            endcase
        end
    end
"""
    lastwordlen = (len(test["ciphertext"]) + len(test["associated_data"])) % 16
    print(template_start)
    print(template % (0, "t_key"))
    for i in range(len(test["ad_words"])):
        print(template % (i+1, "t_ad%d" % i))
    if enc_decn:
        for i in range(len(test["p_words"])):
            print(template % (i+len(test["ad_words"])+1, "t_p%d" % i))
    else:
        for i in range(len(test["c_words"])):
            print(template % (i+len(test["ad_words"])+1, "t_c%d" % i))
        print(template % (len(test["c_words"])+len(test["ad_words"])+1, "t_t"))
    print(template_end)

def gen_keep_assumptions(test, enc_decn):
    template_start = """
    always @(posedge clk) begin
        if (s_valid) begin
            case (s_counter)
"""
    template = "                %d: assume(s_keep == %s);"
    template_end = """
                default: ;
            endcase
        end
    end
"""
    print(template_start)
    print(template % (0, "{16{1'b1}}"))
    for i in range(len(test["ad_words"])):
        print(template % (i+1, "t_ad%d_k" % i))
    if enc_decn:
        for i in range(len(test["p_words"])):
            print(template % (i+len(test["ad_words"])+1, "t_p%d_k" % i))
    else:
        for i in range(len(test["c_words"])):
            print(template % (i+len(test["ad_words"])+1, "t_c%d_k" % i))
    print(template_end)

def gen_last_assumptions(test, enc_decn):
    template_t_s_last = """
        assign t_s_last = s_counter == %d;
"""
    template_t_m_last = """
        assign t_m_last = m_counter == %d;
"""
    template_start = """
    always @(posedge clk) begin
        if (s_valid) begin
"""
    template = """
            assume(s_last == (s_counter == %d || s_counter == %d || s_counter == %d));
"""
    template_end = """
        end
    end
"""
    print(template_start)
    ad_len = len(test["ad_words"])
    p_len  = len(test["p_words"])
    c_len  = len(test["c_words"])
    assert p_len == c_len
    if enc_decn:
        print(template % (-1, -1 if (ad_len == 0) else ad_len, -1 if ((ad_len + p_len) == 0) else (ad_len + p_len))) # Note missing -1 for first word
        print(template_end)
        print(template_t_s_last % (ad_len + p_len))
        print(template_t_m_last % (ad_len + p_len))
    else:
        print(template % (-1 if (ad_len == 0) else ad_len, -1 if ((ad_len + c_len) == 0) else (ad_len + c_len), ad_len + c_len + 1)) # +1 for tag
        print(template_end)
        print(template_t_s_last % (ad_len + c_len + 1))
        print(template_t_m_last % (ad_len + c_len))

def gen_data_assertions(test, enc_decn):
    template_start = """
    integer fi;
    always @(posedge clk) begin
        if (m_valid) begin
            case(m_counter)
"""
    template = """
                %d: begin
                    for (fi = 0; fi < 16; fi = fi + 1) begin
                        if (m_keep[fi]) begin
                            assert(m_data[8*(fi+1)-1-:8] == %s[8*(fi+1)-1-:8]);
                        end
                    end
                end 
"""
    template_end = """
                default: ;
            endcase
        end
    end
"""
    print(template_start)
    ad_len = len(test["ad_words"])
    p_len  = len(test["p_words"])
    output_len = ad_len + p_len + 1
    for i in range(output_len):
        if i < ad_len:
            print(template % (i, "t_ad%d" % i))
        elif i < ad_len + p_len:
            if enc_decn:
                print(template % (i, "t_c%d" % (i-ad_len)))
            else:
                print(template % (i, "t_p%d" % (i-ad_len)))
        else:
            if enc_decn:
                print(template % (i, "t_t"))
            else:
                print(template % (i, "t_zero_word"))
    print(template_end)

def gen_keep_assertions(test, enc_decn):
    template_start = """
    always @(posedge clk) begin
        if (m_valid) begin
            case (m_counter)
"""
    template = "                %d: assert(m_keep == %s);"
    template_end = """
                default: ;
            endcase
        end
    end
"""
    print(template_start)
    for i in range(len(test["ad_words"])):
        print(template % (i+1, "t_ad%d_k" % i))
    if enc_decn:
        for i in range(len(test["p_words"])):
            print(template % (i+len(test["ad_words"])+1, "t_p%d_k" % i))
    else:
        for i in range(len(test["c_words"])):
            print(template % (i+len(test["ad_words"])+1, "t_c%d_k" % i))
    print(template_end)

def gen_last_assertions(test, enc_decn):
    template_start = """
    always @(posedge clk) begin
        if (m_valid) begin
"""
    template = """
            assert(m_last == (m_counter == %d || m_counter == %d || m_counter == %d));
"""
    template_end = """
        end
    end
"""
    print(template_start)
    ad_len = len(test["ad_words"])
    p_len  = len(test["p_words"])
    c_len  = len(test["c_words"])
    assert p_len == c_len
    if enc_decn:
        print(template % (-1 if (ad_len == 0) else ad_len - 1, -1 if ((ad_len + c_len) == 0) else (ad_len + c_len - 1), ad_len + c_len))
        print(template_end)
    else:
        print(template % (-1 if (ad_len == 0) else ad_len - 1, -1 if ((ad_len + c_len) == 0) else (ad_len + p_len - 1), ad_len + c_len)) 
        print(template_end)

def gen_sideband_assertions(test, enc_decn):
    template_start = """
    always @(posedge clk) begin
        if (m_valid) begin
            case(m_counter)
"""
    template = """
                %d: assert(%s);
"""
    template_end = """
                default: ;
            endcase
        end
    end
"""
    print(template_start)
    ad_len = len(test["ad_words"])
    p_len  = len(test["p_words"])
    output_len = ad_len + p_len + 1
    for i in range(output_len):
        if i < ad_len:
            print(template % (i, "m_ad"))
        elif i < ad_len + p_len:
            print(template % (i, "m_p"))
        else:
            print(template % (i, "m_t"))
    print(template_end)

def main():
    inputfile = sys.argv[1]
    tests = parse_testcases(inputfile)
    process_testcases(tests)

    print_comment("Read %d testcases" % len(tests))

    for i, test in enumerate(tests):
        for enc_decn in (True, False):
            gen_generate_header(i, enc_decn)
            gen_data_wires(test)
            gen_keep_wires(test)
            gen_keyword_assumptions(test, enc_decn)
            gen_data_assumptions(test, enc_decn)
            gen_keep_assumptions(test, enc_decn)
            gen_last_assumptions(test, enc_decn)
            gen_data_assertions(test, enc_decn)
            gen_last_assertions(test, enc_decn)
            gen_sideband_assertions(test, enc_decn)
            gen_generate_footer()

main()
