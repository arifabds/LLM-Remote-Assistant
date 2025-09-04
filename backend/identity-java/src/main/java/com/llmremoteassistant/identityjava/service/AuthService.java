package com.llmremoteassistant.identityjava.service;

import com.llmremoteassistant.identityjava.model.User;
import io.smallrye.jwt.build.Jwt;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.BadRequestException;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.mindrot.jbcrypt.BCrypt;
import java.time.Duration;
import java.util.Optional;

@ApplicationScoped
public class AuthService {

    @ConfigProperty(name = "mp.jwt.verify.issuer")
    String issuer;

    @Transactional
    public void registerUser(String username, String password) {
        if (User.find("username", username).firstResultOptional().isPresent()) {
            throw new BadRequestException("Username is already taken");
        }
        User newUser = new User();
        newUser.username = username;
        newUser.password = BCrypt.hashpw(password, BCrypt.gensalt());
        newUser.persist();
    }

    public String loginUser(String username, String password) {
        Optional<User> userOptional = User.find("username", username).firstResultOptional();
        if (userOptional.isEmpty() || !BCrypt.checkpw(password, userOptional.get().password)) {
            throw new BadRequestException("Invalid username or password");
        }
        User user = userOptional.get();
        return Jwt.issuer(issuer)
                  .upn(user.username)
                  .subject(user.id.toString())
                  .expiresIn(Duration.ofHours(24))
                  .sign();
    }
}