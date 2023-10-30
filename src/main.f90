module callback
    use, intrinsic :: iso_fortran_env, only: i8 => int64
    use :: curl, only: c_f_str_ptr
    implicit NONE

    public :: response_callback
    private

    type, public :: response_type
        character (len=:), allocatable :: content
    end type response_type
contains
    ! static size_t callback(char *ptr, size_t size, size_t nmemb, void *data)
    function response_callback(ptr, size, nmemb, client_data) bind(c)
        use, intrinsic :: iso_c_binding, only: c_associated, c_f_pointer, c_ptr, c_size_t
        type (c_ptr),            intent(in), value :: ptr, client_data
        integer (kind=c_size_t), intent(in), value :: size, nmemb
        integer (kind=c_size_t)                    :: response_callback
        type (response_type), pointer              :: response
        character (len=:), allocatable             :: buf

        response_callback = int (0, kind=c_size_t)

        if (.not. c_associated (ptr) .or. .not. c_associated (client_data)) return

        call c_f_pointer (client_data, response)
        if (.not. allocated (response%content)) response%content = ''

        call c_f_str_ptr (ptr, buf, int (nmemb, kind=i8))
        if (.not. allocated (buf)) return
        response%content = response%content // buf
        deallocate (buf)

        response_callback = nmemb
    end function response_callback
end module callback

program main
    use, intrinsic :: iso_c_binding
    use :: curl
    use :: callback
    implicit NONE

    character (len=10000) :: default_url

    character (len=:), allocatable :: content
    integer                        :: rc
    type (c_ptr)                   :: curl_ptr
    type (response_type), target   :: response

    call get_command_argument (1,default_url)

    content = 'test=fortran'

    rc = curl_global_init (CURL_GLOBAL_DEFAULT)
    curl_ptr = curl_easy_init()
    if (.not. c_associated (curl_ptr)) stop 'Error: curl_easy_init() failed'

    ! Set curl options.
    rc = curl_easy_setopt (curl_ptr, CURLOPT_URL,            trim (default_url))
    rc = curl_easy_setopt (curl_ptr, CURLOPT_VERBOSE,        0)
    rc = curl_easy_setopt (curl_ptr, CURLOPT_NOPROGRESS,     1);
    rc = curl_easy_setopt (curl_ptr, CURLOPT_HTTP_VERSION,   CURL_HTTP_VERSION_1_0);
    rc = curl_easy_setopt (curl_ptr, CURLOPT_HTTP09_ALLOWED, 1);    
    rc = curl_easy_setopt (curl_ptr, CURLOPT_WRITEFUNCTION,  c_funloc (response_callback))
    rc = curl_easy_setopt (curl_ptr, CURLOPT_WRITEDATA,      c_loc (response))


    ! Send request.
    rc = curl_easy_perform (curl_ptr)
    call curl_easy_cleanup (curl_ptr)
    call curl_global_cleanup ()

    if (rc /= CURLE_OK) stop 'ERROR curl failed'
    if (.not. allocated (response%content)) stop 'No response data'
    print '(a)', response%content
end program main

