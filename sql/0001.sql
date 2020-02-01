

CREATE TABLE users (
	id INTEGER NOT NULL,
	login CHARACTER VARYING (20) NOT NULL,
	name TEXT NOT NULL,
	status CHARACTER VARYING (20) NOT NULL DEFAULT 'new',

	CONSTRAINT users_pk PRIMARY KEY (id),
	CONSTRAINT users_login_uk UNIQUE (login),
	CONSTRAINT users_status_enum_ck CHECK (
		status IN ('new', 'active', 'admin', 'archived')
	)
);

CREATE TABLE users_crypto_data (
	user_id INTEGER NOT NULL,
	kdf_params TEXT NOT NULL,
	pubk TEXT NOT NULL,
	encrypted_privk TEXT NOT NULL,

	CONSTRAINT users_crypto_data_pk PRIMARY KEY (user_id),
	CONSTRAINT users_crypto_data_fk FOREIGN KEY (user_id)
		REFERENCES users (id)
		ON DELETE RESTRICT
);

CREATE TABLE groups (
	id INTEGER NOT NULL,
	name TEXT NOT NULL,
	pubk TEXT NOT NULL,

	CONSTRAINT groups_pk PRIMARY KEY (id),
	CONSTRAINT groups_name_uk UNIQUE (name)
);

CREATE TABLE group_members (
	user_id INTEGER NOT NULL,
	group_id INTEGER NOT NULL,
	encrypted_privk TEXT NOT NULL,

	CONSTRAINT group_members_pk PRIMARY KEY (user_id, group_id),
	CONSTRAINT group_members_users_fk FOREIGN KEY (user_id)
		REFERENCES users (id)
		ON DELETE CASCADE,
	CONSTRAINT group_members_groups_fk FOREIGN KEY (group_id)
		REFERENCES groups (id)
		ON DELETE CASCADE
);

CREATE TABLE secrets (
	id INTEGER NOT NULL,
	value_author_id INTEGER NOT NULL,
	meta_author_id INTEGER NOT NULL,

	CONSTRAINT secrets_pk PRIMARY KEY (id),
	CONSTRAINT secrets_value_author_fk FOREIGN KEY (value_author_id)
		REFERENCES users (id)
		ON DELETE RESTRICT,
	CONSTRAINT secrets_meta_author_fk FOREIGN KEY (meta_author_id)
		REFERENCES users (id)
		ON DELETE RESTRICT
);

CREATE TABLE secret_values (
	secret_id INTEGER NOT NULL,
	group_id INTEGER NOT NULL,
	ciphertext TEXT NOT NULL,
	encrypted_metadata TEXT NOT NULL,

	CONSTRAINT secret_values_pk PRIMARY KEY (secret_id, group_id),
	CONSTRAINT secret_values_secrets_fk FOREIGN KEY (secret_id)
		REFERENCES secrets (id)
		ON DELETE CASCADE,
	CONSTRAINT secret_values_groups_fk FOREIGN KEY (group_id)
		REFERENCES groups (id)
		ON DELETE CASCADE
);
