package com.llmremoteassistant.identityjava.model;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.*;
import java.time.LocalDateTime;
import org.hibernate.annotations.CreationTimestamp;

@Entity
@Table(name = "devices")
public class Device extends PanacheEntityBase {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    public Long id;

    @Column(nullable = false)
    public String name;
    
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    public ClientType clientType; 

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    public OsType osType;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    public DeviceStatus status;

    @CreationTimestamp
    @Column(nullable = false, updatable = false)
    public LocalDateTime pairedAt;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    public User user;
}