#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <err.h>
#include <errno.h>
#include <string.h>
#include <fcntl.h>

#include <pwd.h>

#include <netdb.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <arpa/inet.h>

#include <sys/types.h>
#include <sys/param.h>

#include <ypclnt.h>
#include <rpcsvc/yp.h>
#include <rpcsvc/ypclnt.h>

#include "yp_client.h"

typedef struct yp_context {
	char	*domain;
	char	*server;
	CLIENT	*client;
	int	 yp_error;
	int	socket;
	uint16_t	local_port;	// Network byte order
	struct sockaddr_storage	server_sockaddr;
} yp_context_t;

static const char *
yp_client_errors[] = {
#define STRIFY(x) [x] = #x
	STRIFY(YP_CLIENT_SUCCESS),
	STRIFY(YP_CLIENT_NOMATCH),
	STRIFY(YP_CLIENT_NODOMAIN),
	STRIFY(YP_CLIENT_YPBIND),
	STRIFY(YP_CLIENT_RPCERROR),
	STRIFY(YP_CLIENT_AUTHERR),
	STRIFY(YP_CLIENT_TIMEOUT),
	STRIFY(YP_CLIENT_NOHOST),
	STRIFY(YP_CLIENT_ENOMEM),
	STRIFY(YP_CLIENT_CONNERR),
	STRIFY(YP_CLIENT_BADARG),
	STRIFY(YP_CLIENT_ERRNO),
#undef STRIFY
};

/*
 * Does the grunt work of talking to ypbind on localhost.
 */

static int
_do_ypbind(const char *domain, struct sockaddr_storage *ss)
{
	// At least one of these should exist if ypbind is running
	static const char *files[] = {
		"/var/run/ypbind.pid",
		"/var/run/ypbind.lock",
		NULL,
	};
	size_t indx;
	int noypbind = 1;
	
	struct sockaddr_in ypbind_sin = { 0 };
	int client_sock = RPC_ANYSOCK;
	int rv = YP_CLIENT_SUCCESS;
	struct ypbind_resp bind_response = { 0 };
	CLIENT *ypbind_client = NULL;
	struct timeval tv = { .tv_sec = 5, };

	ypbind_sin.sin_family = AF_INET;	// Only IPv4 for now?
	ypbind_sin.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
	
	// Let's see if ypbind is running
	for (indx = 0; files[indx]; indx++) {
		if (access(files[indx], 0) != -1) {
			noypbind = 0;
			break;
		}
	}
	if (noypbind)
		return YP_CLIENT_YPBIND;
	
	ypbind_client = clnttcp_create(&ypbind_sin,
				       YPBINDPROG, YPBINDVERS, &client_sock,
				       0, 0);
	if (ypbind_client == NULL) {
		switch (rpc_createerr.cf_stat) {
		case RPC_PROGNOTREGISTERED:
			warnx("ypbind program not registered on localhost");
			rv = YP_CLIENT_YPBIND;
			break;
		default:	// Should probably handle more errors
			rv = YP_CLIENT_RPCERROR;
			break;
		}
		return rv;
	}
	if (ntohs(ypbind_sin.sin_port) >= IPPORT_RESERVED) {
		if (ypbind_client)
			clnt_destroy(ypbind_client);
		return YP_CLIENT_AUTHERR;
	}
	rv = clnt_call(ypbind_client,
		       YPBINDPROC_DOMAIN,
		       (xdrproc_t)xdr_domainname, &domain,
		       (xdrproc_t)xdr_ypbind_resp, &bind_response, tv);
	clnt_destroy(ypbind_client);
	if (rv != RPC_SUCCESS) {
		if (rv == RPC_PROGUNAVAIL || rv == RPC_PROCUNAVAIL) {
			return YP_CLIENT_YPBIND;
		}
		warnx("ypbind for domain %s not responding", domain);
		return YP_CLIENT_TIMEOUT;
	}
	/*
	 * Okay, at this point, bind_response has the information we need.
	 */
	bzero(&ypbind_sin, sizeof(ypbind_sin));
	ypbind_sin.sin_family = AF_INET;	// Still only IPv6
	bcopy(&bind_response.ypbind_resp_u.ypbind_bindinfo.ypbind_binding_addr,
	      &ypbind_sin.sin_addr.s_addr,
	      sizeof(ypbind_sin.sin_addr.s_addr));
	bcopy(&bind_response.ypbind_resp_u.ypbind_bindinfo.ypbind_binding_port,
	      &ypbind_sin.sin_port,
	      sizeof(ypbind_sin.sin_port));
	bcopy(&ypbind_sin, ss, sizeof(ypbind_sin));
	return YP_CLIENT_SUCCESS;
}

/*
 * Given the sockaddr, attempt to create an RPC client for YP.
 * It also binds it to a socket, for later checking.
 */
static CLIENT *
yp_client_create(struct sockaddr_storage *ss, int *sock, uint16_t *port)
{
	CLIENT *retval = NULL;
	struct sockaddr_storage client = { 0 };
	*sock = RPC_ANYSOCK;
	struct timeval tv = { .tv_sec = 5, };
	
	// Buffer size values taken directly from libc/yp/yplib.c
	retval = clntudp_bufcreate((void*)ss,
				   YPPROG, YPVERS, tv,
				   sock, 1280, 2304);
	if (retval) {
		socklen_t client_len = ss->ss_len;
		(void)fcntl(*sock, F_SETFD, 1);
		// I'll admit I don't understand how this can work
		(void)bind(*sock, (struct sockaddr*)&client, ss->ss_len);
		client.ss_family = AF_INET;	// Still IPv4 only?
		if (getsockname(*sock, (struct sockaddr*)&client, &client_len) == -1) {
			clnt_destroy(retval);
			retval = NULL;
		} else {
			if (client.ss_family == AF_INET) {
				*port = ((struct sockaddr_in*)&client)->sin_port;
			} else if (client.ss_family == AF_INET6) {
				*port = ((struct sockaddr_in6*)&client)->sin6_port;
			} else {
				clnt_destroy(retval);
				retval = NULL;
			}
		}
		tv.tv_sec = 1;
		clnt_control(retval, CLSET_RETRY_TIMEOUT, (char*)&tv);
	}
	return retval;
}

/*
 * This doesn't do enough yet.
 * What we really need to do is check to see if the connection
 * is still there, and valid.  If we're using ypbind, we need
 * to see if we're still able to use it for the requested domain
 * (and possibly update the address we got).
 *
 * So the question is how to do all that?
 */
static int
check_yp_client(yp_context_t *ctx)
{
	struct sockaddr_storage check = { 0 };
	socklen_t checklen = sizeof(check);
	int rv;

#define PORT_EQ(ss1, ss2) \
	(ss1.ss_family == AF_INET ?					\
	  (((struct sockaddr_in*)&ss1)->sin_port == ((struct sockaddr_in*)&ss2)->sin_port) : \
	 (((struct sockaddr_in6*)&ss1)->sin6_port == ((struct sockaddr_in6*)&ss2)->sin6_port))
	
	check.ss_family = ctx->server_sockaddr.ss_family;
	if (getsockname(ctx->socket, (struct sockaddr*)&check, &checklen) == -1 ||
	    check.ss_family != ctx->server_sockaddr.ss_family ||
	    (check.ss_family != AF_INET && check.ss_family != AF_INET6) ||
	    !PORT_EQ(check, ctx->server_sockaddr)) {
		return 0;
	}
	return 1;
}

int
yp_client_error(void *ctx)
{
	yp_context_t *context = ctx;

	return context->yp_error;
}
const char *
yp_client_errstr(unsigned int  error)
{
	static const size_t max_err = sizeof(yp_client_errors) / sizeof(yp_client_errors[0]);
	if (error > max_err)
		return NULL;
	return yp_client_errors[error];
	
}
const char *
yp_client_domain(void *ctx)
{
	yp_context_t *context = ctx;
	return context->domain;
}
const char *
yp_client_server(void *ctx)
{
	yp_context_t *context = ctx;
	return context->server;
}

/*
 * For now, this is simply a routine to call
 * YPPROC_MAPLIST, to verify the domain.  If it
 * fails, we return an error.
 */
static int
check_maplist(yp_context_t *context)
{
	struct ypresp_maplist foo = {};
	struct timeval tv = { .tv_sec = 5, };
	int rv;

	rv = clnt_call(context->client, YPPROC_MAPLIST,
		       (xdrproc_t)xdr_domainname, &context->domain,
		       (xdrproc_t)xdr_ypresp_maplist, &foo, tv);
	if (rv != RPC_SUCCESS) {
		return YP_CLIENT_RPCERROR;
	}
	if (ypprot_err(foo.stat)) {
		rv = YP_CLIENT_NODOMAIN;
	} else
		rv = 0;
	xdr_free((xdrproc_t)xdr_ypresp_maplist, &foo);
	return rv;
	
}

void *
yp_client_init(const char *domain, const char *server, int *errorp)
{
	void *retval = NULL;
	yp_context_t *context = NULL;
	struct sockaddr_storage ss = { 0 };
	char default_domain[MAXHOSTNAMELEN] = { 0 };
	const char *server_name = NULL;
	CLIENT *yp_client = NULL;
	int client_sock = RPC_ANYSOCK;
	int local_sock = -1;
	uint16_t local_port = -1;
	int rv;
	
	if (domain == NULL) {
		rv = getdomainname(default_domain, sizeof(default_domain));
		if (rv == -1) {
			if (errorp)
				*errorp = YP_CLIENT_ERRNO;
			goto done;
		}
		if (default_domain[0] == 0) {
			if (errorp)
				*errorp = YP_CLIENT_NODOMAIN;
			goto done;
		}
		domain = default_domain;
	}
	if (server == NULL) {
		rv = _do_ypbind(domain, &ss);
		if (rv != YP_CLIENT_SUCCESS) {
			if (errorp)
				*errorp = rv;
			goto done;
		}
	} else {
		struct addrinfo *ai, pai = { 0 };
		pai.ai_family = AF_INET;
		pai.ai_flags = AI_NUMERICSERV;
		
		rv = getaddrinfo(server, "0", &pai, &ai);
		if (rv != 0) {
			if (errorp)
				*errorp = YP_CLIENT_NOHOST;
			goto done;
		}
		// Yes, we only use one address; it's possible this should change
		bcopy(ai->ai_addr, &ss, ai->ai_addrlen);
		freeaddrinfo(ai);
		server_name = server;
	}
	/*
	 * At this point, we have a domain, a server address, and (optionally)
	 * a server name.  Let's see if we can get a UDP CLIENT from it.
	 */
	yp_client = yp_client_create(&ss, &local_sock, &local_port);

	if (yp_client) {
		// Okay, let's do the magic
		context = calloc(1, sizeof(*context));
		if (context == NULL) {
			clnt_destroy(yp_client);
			if (errorp)
				*errorp = YP_CLIENT_ENOMEM;
		} else {
			int error;
			context->domain = strdup(domain);
			context->server = server ? strdup(server) : NULL;
			context->client = yp_client;
			context->socket = local_sock;
			context->local_port = local_port;
			context->server_sockaddr = ss;
			context->yp_error = YP_CLIENT_SUCCESS;
			error = check_maplist(context);
			if (error) {
				*errorp = error;
				yp_client_close((void*)context);
			} else {
				retval = (void*)context;
			}
		}
	} else {
		warn("Could not connect to server");
		if (errorp)
			*errorp = YP_CLIENT_CONNERR;
	}
done:
	return retval;
}

void
yp_client_close(void *ctx)
{
	yp_context_t *context = ctx;

	if (context->domain)
		free(context->domain);
	if (context->server)
		free(context->server);
	if (context->client)
		clnt_destroy(context->client);
	free(ctx);
}

int
yp_client_match(void *ctx,
		const char *inmap,
		const char *inkey, size_t inkeylen,
		char **outval, size_t *outvallen)
{
	yp_context_t *context = ctx;
        struct ypresp_val yprv = { 0 };
	struct timeval tv = { .tv_sec = 5, };
	struct ypreq_key yprk;
	int rv;
	
	if (ctx == NULL) {
		errno = EFAULT;
		return -1;
	}

	if (inkey == NULL || strlen(inkey) == 0 || inkeylen <= 0 ||
	    inmap == NULL || strlen(inmap) == 0) {
		context->yp_error = YP_CLIENT_BADARG;
		return -1;
	}
	
	yprk.domain = context->domain;
	yprk.map = (char*)inmap;
	yprk.key.keydat_val = (char*)inkey;
	yprk.key.keydat_len = inkeylen;

	rv = clnt_call(context->client, YPPROC_MATCH,
		       (xdrproc_t)xdr_ypreq_key, &yprk,
		       (xdrproc_t)xdr_ypresp_val, &yprv, tv);
	if (rv != RPC_SUCCESS) {
		context->yp_error = YP_CLIENT_RPCERROR;
		rv = -1;
	} else {
		size_t tmp_len;
		char *tmp;

		if (yprv.stat != YP_TRUE) {
			warnx("%s(%p, %s, %s, %zu, %p, %p): yp returned %d", __FUNCTION__, ctx, inmap, inkey, inkeylen, outval, outvallen, yprv.stat);

			switch (yprv.stat) {
			case YP_NOMAP:
			case YP_NOKEY:
				// These seem to mean no entry
				context->yp_error = YP_CLIENT_NOMATCH;
				break;
			default:
				// Calling the rest einval
				context->yp_error = YP_CLIENT_BADARG;
				break;
			}
			rv = -1;
		} else {
			tmp_len = yprv.val.valdat_len;
			tmp = calloc(1, tmp_len+1);
			if (tmp) {
				bcopy(yprv.val.valdat_val, tmp, tmp_len);
				tmp[tmp_len] = 0;
				*outvallen = tmp_len;
				*outval = tmp;
				context->yp_error = YP_CLIENT_SUCCESS;
				rv = 0;
			} else {
			context->yp_error = YP_CLIENT_ENOMEM;
			rv = ENOMEM;
			}
		}
		xdr_free((xdrproc_t)xdr_ypresp_val, &yprv);
	}
	return rv;
}

int
yp_client_first(void *ctx,
		const char *inmap,
		const char **outkey, size_t *outkeylen,
		const char **outval, size_t *outvallen)
{
	yp_context_t *context = ctx;
        struct ypresp_key_val yprkv = { 0 };
	struct timeval tv = { .tv_sec = 5, };
	struct ypreq_key yprk = { };
	int rv;
	
	if (ctx == NULL)
		return (EINVAL);

	if (inmap == NULL || strlen(inmap) == 0) {
		context->yp_error = YP_CLIENT_BADARG;
		return (EINVAL);
	}
	
	yprk.domain = context->domain;
	yprk.map = (char*)inmap;

	rv = clnt_call(context->client, YPPROC_FIRST,
		       (xdrproc_t)xdr_ypreq_nokey, &yprk,
		       (xdrproc_t)xdr_ypresp_key_val, &yprkv, tv);
	if (rv != RPC_SUCCESS) {
		context->yp_error = YP_CLIENT_RPCERROR;
		warnx("YPPROC_FIRST failed with %d", rv);
	} else {
		if (ypprot_err(yprkv.stat) == 0) {
			size_t tmp_len;
			char *tmp;

			tmp_len = yprkv.key.keydat_len;
			tmp = calloc(1, tmp_len+1);
			if (tmp) {
				bcopy(yprkv.key.keydat_val, tmp, tmp_len);
				tmp[tmp_len] = 0;
				*outkey = tmp;
				*outkeylen = tmp_len;
				

				tmp_len = yprkv.val.valdat_len;
				tmp = calloc(1, tmp_len+1);
				if (tmp) {
					bcopy(yprkv.val.valdat_val, tmp, tmp_len);
					tmp[tmp_len] = 0;
					*outvallen = tmp_len;
					*outval = tmp;
					rv = 0;
				} else {
					free((void*)*outkey);
					*outkey = NULL;
					context->yp_error = YP_CLIENT_ENOMEM;
					rv = ENOMEM;
				}
			} else {
				context->yp_error = YP_CLIENT_ENOMEM;
				rv = ENOMEM;
			}
		} else {
			switch (yprkv.stat) {
			case YP_NODOM:
				// I think this means the server doesn't know our domain
//				warnx("%s(%d):  domain should be %s", __FUNCTION__, __LINE__, context->domain);
				context->yp_error = YP_CLIENT_NODOMAIN; break;
			case YP_NOMAP:
				// I think this means the map doesn't exist
//				warnx("%s(%d):  map should be %s", __FUNCTION__, __LINE__, inmap);
				context->yp_error = YP_CLIENT_NOMAP; break;
			case YP_NOKEY:
				context->yp_error = YP_CLIENT_NOKEY; break;
			case YP_BADOP:
			case YP_BADDB:
			case YP_YPERR:
			case YP_BADARGS:
			case YP_VERS:
			default:
				context->yp_error = YP_CLIENT_BADARG; break;
			}
			rv = -1;	// Generic error return value
		}
		xdr_free((xdrproc_t)xdr_ypresp_val, &yprkv);
	}
	return rv;
}

int
yp_client_next(void *ctx,
	       const char *inmap,
	       const char *inkey, size_t inkeylen,
	       const char **outkey, size_t *outkeylen,
	       const char **outval, size_t *outvallen)
{
	yp_context_t *context = ctx;
	struct ypresp_key_val yprkv = { 0 };
	struct ypreq_key yprk = { 0 };
	struct timeval tv = { .tv_sec = 5, };
	int rv;
	
	if (ctx == NULL)
		return -1;

	if (inkey == NULL || strlen(inkey) == 0 || inkeylen <= 0 ||
	    inmap == NULL || strlen(inmap) == 0) {
		context->yp_error = YP_CLIENT_BADARG;
		return -1;
	}

	yprk.domain = context->domain;
	yprk.map = (char*)inmap;
	yprk.key.keydat_val = (char*)inkey;
	yprk.key.keydat_len = inkeylen;

	rv = clnt_call(context->client, YPPROC_NEXT,
		       (xdrproc_t)xdr_ypreq_key, &yprk,
		       (xdrproc_t)xdr_ypresp_key_val, &yprkv, tv);
	if (rv != RPC_SUCCESS) {
		context->yp_error = YP_CLIENT_RPCERROR;
		warnx("YPPROC_MATCH failed with %d", rv);
		rv = -1;
	} else if (ypprot_err(yprkv.stat) == 0) {
		size_t tmp_len;
		char *tmp;

		tmp_len = yprkv.key.keydat_len;
		tmp = calloc(1, tmp_len+1);
		if (tmp) {
			bcopy(yprkv.key.keydat_val, tmp, tmp_len);
			tmp[tmp_len] = 0;
			*outkey = tmp;
			*outkeylen = tmp_len;
			

			tmp_len = yprkv.val.valdat_len;
			tmp = calloc(1, tmp_len+1);
			if (tmp) {
				bcopy(yprkv.val.valdat_val, tmp, tmp_len);
				tmp[tmp_len] = 0;
				*outvallen = tmp_len;
				*outval = tmp;
				rv = 0;
			} else {
				free((void*)*outkey);
				*outkey = NULL;
				context->yp_error = YP_CLIENT_ENOMEM;
				rv = -1;
			}
		} else {
			context->yp_error = YP_CLIENT_ENOMEM;
			rv = -1;
		}
		xdr_free((xdrproc_t)xdr_ypresp_val, &yprkv);
	} else {
		rv = ypprot_err(yprkv.stat);
		switch (rv) {
		case YPERR_NOMORE:
			*outkey = NULL;
			*outkeylen = 0;
			rv = 0;
			break;
		default:
			context->yp_error = YP_CLIENT_RPCERROR;
			rv = -1;
		}
	}
	return rv;
}

/*
 * This one is a bit of a weird function.  First, I'm not calling
 * the RPC directly; instead, I'm using -lypclnt's function for changing
 * the password.  Second, the new_pwent parameter is struct passwd.
 * Note that if changing the password, it must be in its enrypted form here.
 * (old_password is not encrypted.)
 */
int
yp_client_update_pwent(void *ctx, const char *old_password, const struct passwd *new_pwent)
{
	yp_context_t *context = ctx;
	ypclnt_t *ypclnt = NULL;
	char numeric_host[INET_ADDRSTRLEN+1] = { 0 };
	struct sockaddr_in *sin;
	const char *map = "passwd.byname";

	// Only IPv4 is supported for now
	sin = (struct sockaddr_in*)&context->server_sockaddr;
	if (inet_ntop(AF_INET, &sin->sin_addr,
		      numeric_host, sizeof(numeric_host)) == NULL) {
		return EINVAL;
	}

	ypclnt = ypclnt_new(context->domain, map, numeric_host);
	if (ypclnt == NULL) {
		return ENOMEM;
	}
	if (ypclnt_connect(ypclnt) == -1) {
		ypclnt_free(ypclnt);
		return ECONNREFUSED;
	}
	if (ypclnt_passwd(ypclnt, new_pwent, old_password) == -1) {
		ypclnt_free(ypclnt);
		return EPERM;
	}
	ypclnt_free(ypclnt);
	return 0;
}

#ifdef TEST
int
main(int ac, char **av)
{
	void *ctx;
	const char *domain = NULL;
	const char *server = NULL;
	const char *user = "testuser";

	if (ac > 1)
		domain = av[1];
	if (ac > 2)
		server = av[2];
	if (ac > 3)
		user = av[3];
	if (ac > 4)
		errx(1, "Usage: %s [domain [server [user]]]", av[0]);

	ctx = yp_client_init(domain, server);
	if (ctx == NULL)
		err(1, "Could not create YP context");
	else {
		const char *map = "passwd.byname";
		const char *out_val;
		const char *first_key = NULL, *next_key = NULL;
		size_t first_keylen, next_keylen, out_len;
		int x;
		struct passwd pwent = {};
		
		x = yp_client_match(ctx, map, user, strlen(user), 
				    &out_val, &out_len);
		if (x == 0) {
			printf("got %s\n", out_val);
		} else {
			warnc(x, "Returned %d", x);
		}
		printf("Now trying yp_client_first/yp_client_next\n");
		for (x = yp_client_first(ctx, map,
					 &next_key, &next_keylen,
					 &out_val, &out_len);
		     x == 0;
		     x =  yp_client_next(ctx, map,
					 first_key, first_keylen,
					 &next_key, &next_keylen,
					 &out_val, &out_len))
		{
			printf("x = %d, first_key = `%s', out_val = `%s'\n",
			       x, first_key, out_val);
			free((void*)first_key);
			free((void*)out_val);
			first_key = next_key;
			first_keylen = next_keylen;
			next_key = NULL;
		}
		printf("x = %d\n", x);
		printf("Now trying to change password entry\n");
		pwent.pw_name = "testuser";
		pwent.pw_uid = 2000;
		pwent.pw_gid = 2000;
		pwent.pw_passwd = "";
		pwent.pw_gecos = "Test user";
		pwent.pw_dir = "/nonexistent";
		pwent.pw_shell = "/bin/csh";
		pwent.pw_class = "";
		x = yp_client_update_pwent(ctx, "", &pwent);
		printf("x = %d\n", x);
	}
	return 0;
}
#endif /* TEST */
