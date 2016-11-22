#ifndef _YP_H
# define _YP_H

struct passwd;

enum yp_client_error {
	YP_CLIENT_SUCCESS = 0,
	YP_CLIENT_NOMATCH,	// Key not found
	YP_CLIENT_NODOMAIN,	// No domain given
	YP_CLIENT_NOMAP,	// No map given
	YP_CLIENT_NOKEY,	// No key given
	YP_CLIENT_YPBIND,	// Unable to reach ypbind on localhost
	YP_CLIENT_RPCERROR,	// Generic RPC error
	YP_CLIENT_AUTHERR,	// Authorization error
	YP_CLIENT_TIMEOUT,	// Time-out error, may be worth trying again
	YP_CLIENT_NOHOST,	// Unable to resolve a hostname
	YP_CLIENT_ENOMEM,	// No memory, aka ENOMEM
	YP_CLIENT_CONNERR,	// Generic connection error
	YP_CLIENT_BADARG,	// Invalid argument to a function, aka EINVAL
	YP_CLIENT_ERRNO,	// Check errno for error
};

/*
 * Return a context object to connect to the given
 * server for the given domain.
 * If domain is NULL, it will use getdomainname();
 * if that fails, it returns NULL and sets errno.
 * (If no domainname is set, it sets errno to ENOENT.)
 * If server is NULL, then it will query ypbind on
 * localhost; if that fails, it returns NULL and sets
 * errno.
 * If it cannot connect to the server for the domain,
 * 
 */
void *yp_client_init(const char *domain, const char *server, int *errorp);
void yp_client_close(void *context);

int yp_client_match(void *context,
		    const char *inmap,
		    const char *inkey,
		    size_t inkeylen,
		    char **outval,
		    size_t *outvallen);

int yp_client_first(void *context, const char *inmap,
		    const char **outkey, size_t *outkeylen,
		    const char **outval, size_t *outvallen);

int yp_client_next(void *context, const char *inmap,
		   const char *inkey, size_t inkeylen,
		   const char **outkey, size_t *outkeylen,
		   const char **outval, size_t *outvallen);

int yp_client_update_pwent(void *ctx,
			   const char *old_password, // Unencrypted!
			   const struct passwd *new_pwent);

int yp_client_error(void *ctx);
const char *yp_client_domain(void *ctx);
const char *yp_client_server(void *ctx);

const char *yp_client_errstr(unsigned int error);

#endif /* _YP_H */
