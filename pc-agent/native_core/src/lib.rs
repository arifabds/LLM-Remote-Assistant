use once_cell::sync::Lazy;
use regex::Regex;
use pyo3::prelude::*;

static DANGEROUS_PATTERN: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r#"\b(os|shutil|subprocess|sys|rmtree|remove|system|execute|eval|exec)\b"#).unwrap()
});

fn analyze_code_internal(code: &str) -> bool {
    !DANGEROUS_PATTERN.is_match(code)
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
    fn test_safe_code() {
        let safe_code = "print('Hello, world!')\nresult = 2 + 2";
        assert_eq!(analyze_code_internal(safe_code), true);
    }

    #[test]
    fn test_dangerous_code_with_os() {
        let dangerous_code = "import os\nos.system('rm -rf /')";
        assert_eq!(analyze_code_internal(dangerous_code), false);
    }
    
    #[test]
    fn test_dangerous_code_with_subprocess() {
        let dangerous_code = "import subprocess\nsubprocess.run(['ls'])";
        assert_eq!(analyze_code_internal(dangerous_code), false);
    }
    
    #[test]
    fn test_dangerous_code_with_shutil() {
        let dangerous_code = "import shutil\nshutil.rmtree('/some/dir')";
        assert_eq!(analyze_code_internal(dangerous_code), false);
    }

    #[test]
    fn test_code_with_substring_of_dangerous_word() {
        let code = "process_data = True";
        assert_eq!(analyze_code_internal(code), true);
    }

    #[test]
    fn test_empty_code() {
        let empty_code = "";
        assert_eq!(analyze_code_internal(empty_code), true);
    }
}