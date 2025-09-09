package com.llmremoteassistant.identityjava.model;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.*;
import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.Set;
import org.hibernate.annotations.CreationTimestamp;

@Entity
@Table(name = "users")
public class User extends PanacheEntityBase {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    public Long id;

    @Column(unique = true, nullable = false)
    public String username;

    @Column(nullable = false, length = 60)
    public String password;

    @CreationTimestamp
    @Column(nullable = false, updatable = false)
    public LocalDateTime createdAt;
    
    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "user_pairing_tokens", joinColumns = @JoinColumn(name = "user_id"))
    @Column(name = "pairing_token")
    public Set<String> activePairingTokens = new HashSet<>();
}