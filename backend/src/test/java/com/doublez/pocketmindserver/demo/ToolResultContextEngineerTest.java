package com.doublez.pocketmindserver.demo;

import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;

class ToolResultContextEngineerTest {

    @Test
    void shouldTrimAndKeepImportantLinesForBash() {
        ToolResultContextEngineer engineer = new ToolResultContextEngineer(true, 4, 200);
        String raw = "bash_id: shell_x\n"
                + "random noise line\n"
                + "STDERR:\n"
                + "Exit code: 1\n"
                + "C:/repo/src/Main.java\n"
                + "random noise line\n";

        String processed = engineer.process("Bash", raw);

        Assertions.assertTrue(processed.contains("bash_id: shell_x"));
        Assertions.assertTrue(processed.contains("Exit code: 1"));
        Assertions.assertTrue(processed.contains("Main.java"));
        Assertions.assertFalse(processed.contains("random noise line\nrandom noise line"));
    }

    @Test
    void shouldRespectDisabledFlag() {
        ToolResultContextEngineer engineer = new ToolResultContextEngineer(false, 2, 10);
        String raw = "line1\nline2\nline3";

        String processed = engineer.process("Read", raw);

        Assertions.assertEquals(raw, processed);
    }
}
