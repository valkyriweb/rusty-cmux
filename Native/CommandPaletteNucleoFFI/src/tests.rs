use super::*;

#[test]
fn ffi_search_finds_matching_candidate_and_rejects_invalid_utf8() {
    let blob = b"Open FolderClose Window";
    let spans = [
        CmuxNucleoCandidateSpan {
            title_offset: 0,
            title_len: 11,
            search_offset: 0,
            search_len: 11,
            rank: 0,
        },
        CmuxNucleoCandidateSpan {
            title_offset: 11,
            title_len: 12,
            search_offset: 11,
            search_len: 12,
            rank: 0,
        },
    ];
    unsafe {
        let index =
            cmux_nucleo_index_create(blob.as_ptr(), blob.len(), spans.as_ptr(), spans.len());
        assert!(!index.is_null());
        let mut matches = [CmuxNucleoMatch {
            index: 0,
            score: 0.0,
            rank: 0,
        }; 2];
        let mut count = 0;
        let query = b"folder";
        assert_eq!(
            cmux_nucleo_index_search(
                index,
                query.as_ptr(),
                query.len(),
                2,
                matches.as_mut_ptr(),
                matches.len(),
                &mut count
            ),
            0
        );
        assert_eq!(count, 1);
        assert_eq!(matches[0].index, 0);
        let invalid = [0xff];
        assert_eq!(
            cmux_nucleo_index_search(
                index,
                invalid.as_ptr(),
                invalid.len(),
                2,
                matches.as_mut_ptr(),
                matches.len(),
                &mut count
            ),
            -2
        );
        assert_eq!(count, 0);
        cmux_nucleo_index_destroy(index);
    }
}
