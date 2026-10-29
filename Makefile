GOOSE ?= goose

c4_solve: c4_solve.goose
	$(GOOSE) build c4_solve.goose -o c4_solve

# Exact scores, node counts and table statistics; the timing text is filtered out.
test: c4_solve
	./c4_solve < inputs | sed 's| / [0-9]* msec.*||' | diff expected.txt -

bench: c4_solve
	./c4_solve < inputs

clean:
	rm -f c4_solve

.PHONY: test bench clean
